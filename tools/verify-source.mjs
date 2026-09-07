import assert from 'node:assert/strict';
import {existsSync,readFileSync,readdirSync,statSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
function files(dir) { return readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(join(dir,e.name)):[join(dir,e.name)]); }
const lock=JSON.parse(readFileSync('assets.lock.json','utf8'));
assert.equal(lock.version,2);
const media=files('assets').filter(f=>/\.(png|jpe?g|webp|ttf|otf|wav|ogg|mp4)$/i.test(f));
assert.equal(media.length,198,'Act 1 media inventory');
assert.deepEqual([...Object.keys(lock.assets)].sort(),media.sort());
for(const file of media) {
  const entry=lock.assets[file];
  assert.equal(entry.size,statSync(file).size,file);
  assert.equal(entry.sha256,'sha256:'+createHash('sha256').update(readFileSync(file)).digest('hex'),file);
  assert.match(entry.path,/^https:\/\/(?:d1oupeiobkpcny\.cloudfront\.net|files\.manuscdn\.com)\//,file);
  assert(!entry.path.includes('?'),file);
}
for(const old of ['scripts/template','scenes/template','resources/template','assets/template','art','audio']) assert(!existsSync(old),old);
assert.match(readFileSync('project.godot','utf8'),/run\/main_scene="res:\/\/scenes\/main\/main.tscn"/);
// Godot may reorder top-level keys; retain complete multiline values so input
// dictionaries and serialized objects cannot silently drift from the scaffold.
function projectSettings(text) {
  let section='', key=null, value=[]; const result={};
  const finish=()=> { if(key!==null) { assert(!(key in result),`duplicate setting ${key}`); result[key]=value.join('\n'); } };
  for(const raw of text.split('\n')) {
    const line=raw.trim();
    if(!line || line.startsWith(';')) continue;
    if(/^\[[^\]]+\]$/.test(line)) { finish(); key=null; section=line; }
    else if(/^[A-Za-z_][A-Za-z_0-9/]*=/.test(line)) {
      finish(); const split=line.indexOf('='); key=section+line.slice(0,split); value=[line.slice(split+1)];
    } else { assert(key!==null,'orphan project setting'); value.push(line); }
  }
  finish(); return result;
}
assert.deepEqual(projectSettings('[application]\nb=2\na=1'),projectSettings('[application]\na=1\nb=2'));
assert.notDeepEqual(projectSettings('[input]\na={\n"events": [Object("Key", "code":1)]\n}'),projectSettings('[input]\na={\n"events": [Object("Key", "code":2)]\n}'));
assert.deepEqual(projectSettings(JSON.parse(readFileSync('template.json','utf8')).files['project.godot']),projectSettings(readFileSync('project.godot','utf8')),'scaffold project settings must match the source');
for(const file of files('resources/narrative/dossiers')) assert(file.includes('/business_'));
for(const file of files('resources/directives/districts')) assert(file.endsWith('/business_pool.tres'));
// Exporting all_resources also packs unregistered .tres files. Follow the actual
// mission catalog, so a retired directive cannot hide behind a Business-only pool.
const directiveResources=new Set();
const directiveMedia=new Set();
function visitDirectives(file) {
  if(directiveResources.has(file)) return;
  const text=readFileSync(file,'utf8');
  if(file.startsWith('resources/directives/')) {
    directiveResources.add(file);
    assert.match(text,/district_id = &"BUSINESS"/,file);
  }
  for(const [,reference] of text.matchAll(/"res:\/\/([^"\n]+)"/g)) {
    if(reference.startsWith('resources/directives/')) visitDirectives(reference);
    if(reference.startsWith('assets/')) directiveMedia.add(reference);
  }
}
visitDirectives('scripts/directives/district_mission_catalog.gd');
assert.deepEqual(files('resources/directives').filter(f=>f.endsWith('.tres')).sort(),[...directiveResources].sort(),'unregistered directive resources');
assert.deepEqual(media.filter(f=>f.startsWith('assets/ui/directives/')).sort(),[...directiveMedia].sort(),'unregistered directive art');
assert.deepEqual(media.filter(f=>f.startsWith('assets/bosses/animated/')),['assets/bosses/animated/settlement-engine-s04-atlas.webp']);
assert.deepEqual(media.filter(f=>f.startsWith('assets/audio/music/bosses/')),['assets/audio/music/bosses/settlement-engine-s04.ogg']);
for(const file of files('assets').filter(f=>f.endsWith('.import'))) assert(Object.hasOwn(lock.assets,file.slice(0,-7)),`orphan import: ${file}`);
for(const file of [...files('scripts'),...files('resources'),...files('scenes')].filter(f=>/\.(gd|tres|tscn)$/.test(f))) {
  for(const [,reference] of readFileSync(file,'utf8').matchAll(/["']res:\/\/(assets\/[^"'\n]+\.(?:png|jpe?g|webp|ttf|otf|wav|ogg|mp4))["']/g)) {
    assert(Object.hasOwn(lock.assets,reference),`${file}: unlocked media reference ${reference}`);
  }
}
assert.equal((readFileSync('resources/siege/district_contact.tres','utf8').match(/id="\w+Act"/g)||[]).length,1);
const en=JSON.parse(readFileSync('localization/en.json','utf8'));
const zh=JSON.parse(readFileSync('localization/zh-CN.json','utf8'));
assert.deepEqual(Object.keys(en).sort(),Object.keys(zh).sort());
for(const key of Object.keys(en)) assert.deepEqual([...en[key].matchAll(/\{(\w+)\}/g)].map(m=>m[1]).sort(),[...zh[key].matchAll(/\{(\w+)\}/g)].map(m=>m[1]).sort(),key);
console.log(`Act 1 source boundary, ${media.length} local/locked media hashes, and locale parity verified.`);
