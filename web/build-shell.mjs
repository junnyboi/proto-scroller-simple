import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
const dir=dirname(fileURLToPath(import.meta.url));
const lock=JSON.parse(readFileSync(join(dir,'../assets.lock.json'),'utf8'));
const catalogs=Object.fromEntries(['en','zh-CN'].map(locale => [locale,Object.fromEntries(Object.entries(JSON.parse(readFileSync(join(dir,'../localization/'+locale+'.json'),'utf8'))).filter(([key])=>key.startsWith('web.')))]));
const fontSource=JSON.parse(readFileSync(join(dir,'loader-font-source.json'),'utf8'));
const fallbackCss=readFileSync(join(dir,'manus-fonts.css'),'utf8');
const sha256=value=>createHash('sha256').update(value).digest('hex');
const corpus=Object.values(catalogs).flatMap(catalog=>Object.values(catalog)).join('')+['loader.js','i18n.js','loader.css'].map(name=>[...readFileSync(join(dir,name),'utf8')].filter(character=>character.codePointAt(0)>127).join('')).join('');
const fallbackData=fallbackCss.match(/data:font\/woff2;base64,([A-Za-z0-9+/=]+)/)?.[1];
if (sha256(corpus)!==fontSource.corpusSha256 || sha256(fallbackCss)!==fontSource.cssSha256 || !fallbackData || sha256(Buffer.from(fallbackData,'base64'))!==fontSource.woff2Sha256 || sha256(readFileSync(join(dir,'..',fontSource.source)))!==fontSource.sourceSha256) {
  throw new Error('Loader CJK font inputs changed. Run tools/build-loader-cjk-font.py with fonttools[woff]==4.64.0, then rebuild the shell.');
}
let js='const WEB_CATALOGS = '+JSON.stringify(catalogs).replaceAll('<','\\u003c')+';\n'+readFileSync(join(dir,'i18n.js'),'utf8')+'\n'+readFileSync(join(dir,'loader.js'),'utf8');
for (const name of ['title-loop-landscape.mp4','title-loop-portrait.mp4','title-poster-landscape.jpg','title-poster-portrait.jpg']) {
  const key='assets/title-video/'+name;
  if (!lock.assets[key]?.path) throw new Error('Publish title asset before building shell: '+key);
  js=js.replaceAll('__TITLE_ASSETS__/'+name,lock.assets[key].path);
}
const manusFonts=[['Regular',400],['Medium',500],['Bold',700]].map(([style,weight]) => '@font-face{font-family:ManusCC0;src:url("data:font/ttf;base64,'+readFileSync(join(dir,'../assets/fonts/ManusCC0-'+style+'.ttf')).toString('base64')+'") format("truetype");font-style:normal;font-weight:'+weight+';font-display:swap}').join('\n');
const css=manusFonts+'\n'+fallbackCss+'\n'+readFileSync(join(dir,'loader.css'),'utf8');
const html='<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>$GODOT_PROJECT_NAME</title><style>'+css+'</style>$GODOT_HEAD_INCLUDE</head><body><div id="root"></div><script>const GODOT_CONFIG = $GODOT_CONFIG; const GODOT_SCRIPT_URL = "$GODOT_URL";\n'+js+'</script></body></html>\n';
writeFileSync(join(dir,'shell.html'),html);
console.log('Built original loader/title shell from the verified asset lock.');
