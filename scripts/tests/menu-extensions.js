const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const repo = path.resolve(__dirname, '../..');
const model = require(path.join(repo, 'shell/plugins/menu/MenuModel.js'));
const defaults = model.parseMenuJsonc(fs.readFileSync(path.join(repo, 'default/strata/strata-menu.jsonc'), 'utf8'));
const base = model.mergeMenuSources(defaults, []);
const expected = ['style.theme','style.font','install.style.theme','install.webapp','remove.webapp','remove.theme','setup.plugin','setup.plugin.add','setup.typing.input','setup.monitors','setup.config.hyprland','trigger.capture.color','trigger.appearance.top-bar'];
for (const id of expected) {
  assert(base.items[id], `Missing supported Omarchy route ${id}`);
  assert.equal(model.resolveRoute(base.items,base.itemOrder,id),id);
}
for (const id of base.itemOrder) {
  const row=base.items[id];
  if (row.parent) assert(base.items[row.parent],`Orphan row ${id}: ${row.parent}`);
}
const action='strata-shell shell toggle strata.theme-picker';
const merged=model.mergeMenuSources(defaults,model.parseMenuJsonc(JSON.stringify({'style.theme':{action}})));
assert.equal(merged.items['style.theme'].action,action);
assert.equal(merged.items['style.theme'].label,'Themes & backgrounds');
assert.equal(merged.items['style.theme'].icon,base.items['style.theme'].icon);
assert.deepEqual(merged.items['style.theme'].aliases,base.items['style.theme'].aliases);
assert.equal(merged.items['style.theme'].plugin,'strata.theme-picker');
assert.equal(merged.items['style.theme'].parent,'style');
const fixture=model.parseMenuJsonc(`{
 // Leading comment
 "personal": {"label":"Personal"}, // Inline comment
 /* Block comment */ "personal.test": {
  "action":"printf 'https://example.test/a//b, } /* literal */'",
  "target":"setup.plugin", "aliases":["test",],
 },
}`);
assert.equal(fixture.length,2);
assert.equal(fixture[1].action,"printf 'https://example.test/a//b, } /* literal */'");
assert.equal(fixture[1].target,'setup.plugin');
assert.deepEqual(model.parseMenuJsonc('{ /* unterminated'),[]);
const guarded=model.parseMenuJsonc('{"test":{"label":"Test","icon":"x","when":"guard","checked":"check","action":"original"}}');
const custom=model.parseMenuJsonc('{"test":{"action":"new","checked":""}}');
const check=model.mergeMenuSources(guarded,custom).items.test;
assert.equal(check.when,'guard');assert.equal(check.checked,'');assert.equal(check.label,'Test');assert.equal(check.icon,'x');
assert.equal(model.pluginAction('strata-shell shell toggle x.y').method,'toggle');
assert.deepEqual(model.summonAction("strata-shell shell summon x.y '{\"tab\":1}'"),{id:'x.y',payload:'{"tab":1}'});
assert.equal(model.pluginAction('strata-shell shell toggle x.y; echo unsafe'),null);
assert.equal(model.pluginAction('omarchy-shell shell toggle x.y'),null);
assert.equal(model.resolveRoute(base.items,base.itemOrder,'settings'),'setup');
const customRoutes=model.mergeMenuSources(defaults,model.parseMenuJsonc(JSON.stringify({
  'style.theme.custom':{label:'Custom theme',action:'custom-theme'},
  'personal':{label:'Personal'},
  'personal.theme':{label:'Themes',target:'style.theme',parent:'setup.plugin'}
})));
assert.equal(customRoutes.items['style.theme.custom'].parent,'style.theme');
assert.equal(customRoutes.items['personal.theme'].parent,'setup.plugin');
assert.equal(customRoutes.items['personal.theme'].target,'style.theme');
// Extension IDs, parents and targets are literal: no route migration layer.
const literal=model.parseMenuJsonc('{"setup.theme.custom":{"target":"setup.theme","parent":"setup.plugins"}}')[0];
assert.equal(literal.id,'setup.theme.custom');
assert.equal(literal.parent,'setup.plugins');
assert.equal(literal.target,'setup.theme');
assert.equal(model.resolveRoute(base.items,base.itemOrder,'setup.theme'),'setup.theme');
assert(!base.items['setup.theme']);
const cleared=model.mergeMenuSources(defaults,model.parseMenuJsonc('{"style.theme":{"action":"","target":"style.font","plugin":""}}')).items['style.theme'];
assert.equal(cleared.kind,'link');assert.equal(cleared.plugin,'');assert.equal(cleared.label,'Themes & backgrounds');
console.log('PASS: native routes, literal extension IDs, partial merge, plugin targeting, JSONC comments and literal actions');
