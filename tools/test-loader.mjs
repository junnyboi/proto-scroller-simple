import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const catalogs=Object.fromEntries(['en','zh-CN'].map(l=>[l,JSON.parse(readFileSync('localization/'+l+'.json','utf8'))]));
function context(locale) {
  const context=vm.createContext({URLSearchParams,WEB_CATALOGS:catalogs,window:{location:{search:'?locale='+locale},navigator:{language:'en'},localStorage:{getItem(){throw Error('disabled')},setItem(){throw Error('disabled')},removeItem(){throw Error('disabled')}}},document:{documentElement:{}}});
  vm.runInContext(readFileSync('web/i18n.js','utf8')+'\n'+readFileSync('web/loader.js','utf8').split('const ENGINE_SCRIPT_ID')[0],context);
  return expression=>vm.runInContext(expression,context);
}
for(const locale of ['en','zh-CN']) {
 const run=context(locale);
 assert.equal(run('webLocale'),locale);
 assert.equal(run('calculateLoadingPercent(25,100)'),25);
 assert.equal(run('calculateLoadingPercent(-1,100)'),null);
 assert.equal(run('calculateLoadingPercent(1,0)'),null);
 assert.equal(run('calculateLoadingPercent(150,100)'),100);
 assert.equal(run('loadingStage(100)'),catalogs[locale]['web.starting']);
 assert.equal(run('formatEta(null)'),catalogs[locale]['web.calculating']);
 assert.equal(run('formatEta(0)'),catalogs[locale]['web.ready']);
 assert.equal(run('formatEta(5)'),locale==='en'?'5s':'5秒');
 assert.equal(run('formatEta(90)'),locale==='en'?'1m 30s':'1分 30秒');
 assert(!run('webT("web.initializing", {percent:"25%",size:"12 MiB"})').includes('{'));
 assert.equal(run('selectWebLocale("?locale=invalid",{getItem:()=>"zh-CN"},"en")'),'zh-CN');
 assert.equal(run('selectWebLocale("",{getItem:()=>{throw Error()}},"zh-SG")'),'zh-CN');
 assert.equal(run('selectWebLocale("",null,"fr")'),'en');
 assert.equal(run('normalizeWebLocale("zh_CN")'),'zh-CN');
 run('window.protoScrollerSetLocale("en")');
 assert.equal(run('window.protoScrollerLocale'),'en');
 const resolution=run('calculateWebRenderResolution(390,844,3,"performance")');
 assert(resolution.width<=720 && resolution.height<=1280);
}
const html=readFileSync('web/shell.html','utf8');
assert(html.includes('ScrollerCJK'));
assert(!html.includes('__TITLE_ASSETS__'));
console.log('Loader locale selection, blocked storage, translated states, progress/ETA and render bounds passed.');
