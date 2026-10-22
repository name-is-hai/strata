// Exercise settings persistence and config loading without a desktop.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const plain = value => JSON.parse(JSON.stringify(value));
const settings = vm.createContext({});
vm.runInContext(read('shell/plugins/services/stage-control/Settings.js'), settings);
const id = 'strata.stage-control';
const config = {version:1, disabledPlugins:[id], plugins:[{id, highlight:'red',
  desktops:{1:[4]}, desktopNames:{1:'Code'}, desktopLayoutVersion:1}],
  bar:{layout:{left:[{id:'strata.menu'}],center:[{id:'strata.clock'}],right:[]}}};
const source = read('shell/shell.qml');
function functionBody(name) {
  const match = source.match(new RegExp('  function ' + name + '\\([^]*?\\n  \\}'));
  assert.ok(match, name + ' exists');
  return match[0];
}
let writes = 0;
let userText = JSON.stringify(config);
const host = vm.createContext({
  Util:{isPlainObject:value=>!!value && typeof value==='object' && !Array.isArray(value), canonicalWidgetId:id=>id},
  console,
  builtinShellConfig:{version:1,plugins:[{id}]}, defaultsConfig:{version:1, plugins:[{id}]},
  userConfigFile:{text:()=>userText, setText:text=>{writes++;userText=text;}}
});
host.shell = host;
for (const name of ['persistShellConfig', 'applyShellConfig', 'updateEntryInline', 'publicPluginConfig'])
  vm.runInContext(functionBody(name), host);
host.applyShellConfig();
assert.equal(writes, 0, 'loading user settings does not rewrite them');
assert.deepEqual(plain(host.shellConfig), config);
const entry = plain(settings.pluginEntry(host.shellConfig, id));
assert.equal(entry.highlight, 'red');
assert.equal(host.updateEntryInline(id, {...entry, highlight:'green'}), true);
assert.equal(writes, 1);
assert.equal(settings.pluginEntry(host.shellConfig, id).highlight, 'green');
assert.deepEqual(plain(host.shellConfig.bar.layout), config.bar.layout, 'saving keeps settings outside bar');
assert.deepEqual(plain(host.shellConfig.disabledPlugins), [id]);
assert.deepEqual(plain(settings.pluginEntry(host.shellConfig,id).desktops), {1:[4]});
assert.equal(host.updateEntryInline(id, {...entry, highlight:'green'}), false, 'unchanged settings do not rewrite');
const snapshot = host.publicPluginConfig(id);
snapshot.desktopNames[1] = 'Changed copy';
assert.equal(settings.pluginEntry(host.shellConfig,id).desktopNames[1], 'Code', 'scoped API exposes a copy');
assert.equal(host.publicPluginConfig('another.plugin').highlight, undefined);
host.applyShellConfig();
assert.equal(writes, 1, 'reload keeps saved config without writing again');
for (const text of ['', '{invalid', '{"version":2}']) {
  userText = text;
  host.applyShellConfig();
  assert.deepEqual(plain(host.shellConfig), plain(host.defaultsConfig));
  assert.equal(writes, 1, 'falling back to defaults never overwrites user file');
}
host.defaultsConfig = null;
host.applyShellConfig();
assert.deepEqual(plain(host.shellConfig), plain(host.builtinShellConfig));
const defaults = JSON.parse(read('defaults/strata/shell.json'));
for (const section of Object.values(defaults.bar.layout))
  assert.ok(!section.some(entry=>[id,'strata.mouse','strata.microphone'].includes(entry.id)));
assert.ok(defaults.plugins.some(entry=>entry.id===id));
for (const folder of ['services/stage-control','panels/mouse']) {
  const manifest = JSON.parse(read(`shell/plugins/${folder}/manifest.json`));
  assert.deepEqual(manifest.kinds,['service','panel']);
  assert.equal(manifest.entryPoints.barWidget,undefined);
}
assert.equal(fs.existsSync(path.join(root,'shell/services/ConfigMigrations.js')),false);
assert.equal(source.includes('ConfigMigrations'),false);
console.log('PASS: direct config loading, defaults fallback, Stage settings persistence and regular plugin layout');
