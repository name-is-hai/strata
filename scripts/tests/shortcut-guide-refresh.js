// Exercise the real catalog refresh command and Lua observer in isolation.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const repo = path.resolve(__dirname, '../..');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'strata-guide-refresh-'));
try {
  const plugin = path.join(repo, 'shell/plugins/services/shortcut-guide');
  const Model = {};
  vm.createContext(Model);
  vm.runInContext(fs.readFileSync(path.join(plugin,'ServiceModel.js'),'utf8').replace(/^\.pragma library\s*/,''),Model);
  const processState={running:false};
  const root={bridgePath:path.join(plugin,'bridge.lua'),integrationState:'enabled'};
  const state={root,Model,catalogBridgeReloadProcess:processState,
    activeBridgeReloadSourceHash:'',pendingBridgeReloadSourceHash:'',lastBridgeReloadSourceHash:''};
  vm.createContext(state);
  const qml=fs.readFileSync(path.join(plugin,'Service.qml'),'utf8');
  const body=qml.match(/  function requestCatalogBridgeReload\(sourceHash\) \{([\s\S]*?)\n  \}/)[1];
  vm.runInContext('function requestCatalogBridgeReload(sourceHash) {'+body+'\n}',state);
  const hash='sha256:'+'a'.repeat(64);
  assert.equal(state.requestCatalogBridgeReload(hash),true);
  assert.equal(processState.command[0],'hyprctl');
  assert.equal(processState.command[1],'eval','catalog refresh must never reload monitor configuration');
  assert.equal(state.requestCatalogBridgeReload(hash),false,'coalesce an in-flight publication');
  assert.equal(Model.shouldReloadCatalogBridge({ok:true,changed:true,sourceHash:hash},'disabled','','',''),true,
    'turning the guide off must also deactivate its Lua observer');
  const fixture=path.join(dir,'fixture.lua');
  fs.mkdirSync(path.join(dir,'strata/shortcut-guide'),{recursive:true});
  fs.writeFileSync(fixture,`
local catalog_path = os.getenv('XDG_STATE_HOME') .. '/strata/shortcut-guide/bridge-catalog.lua'
local function catalog(enabled)
  local f=assert(io.open(catalog_path,'w'))
  f:write('return { schemaVersion=1, enabled=' .. tostring(enabled) .. ', matches={}, modifierCodes={SUPER={133}, SHIFT={50}, CTRL={37}, ALT={64}} }')
  f:close()
end
local binds, events, notifications = 0, {}, {}
hl = {
  bind=function() binds=binds+1; return binds end,
  on=function(event,callback) assert(not events[event], 'duplicate keyboard observer'); events[event]=callback end,
  dsp={event=function(payload) return payload end},
  dispatch=function(payload) notifications[#notifications+1]=payload end,
  monitor=function() error('catalog refresh touched monitors') end,
  config=function() error('catalog refresh reconfigured compositor') end,
}
local function refresh() ${processState.command[2]} end
-- Startup without a published catalog stays inert.
refresh(); assert(binds==0 and next(events)==nil)
catalog(true); refresh()
assert(binds==20 and events['input.keyboard.key'])
local original = _G.__strata_shortcut_guide_bridge_state
for i=1,10 do refresh() end
assert(binds==20 and original==_G.__strata_shortcut_guide_bridge_state)
events['input.keyboard.key'](133,0,1)
assert(notifications[#notifications]=='strata-shortcuts:v1:guide:down:SUPER')
refresh(); assert(notifications[#notifications]=='strata-shortcuts:v1:guide:cancel')
assert(original.guideRoot==nil and next(original.held.SUPER)==nil)
-- Disabling and malformed catalogs fail closed, without reinstalling handlers.
catalog(false); refresh(); assert(not original.enabled and binds==20)
local count=#notifications; events['input.keyboard.key'](133,0,1); assert(#notifications==count)
local f=assert(io.open(catalog_path,'w')); f:write('invalid lua'); f:close()
refresh(); assert(not original.enabled)
catalog(true); refresh(); assert(original.enabled and next(original.held.SUPER)==nil)
-- A genuine compositor config reload still restores its pointer bindings.
assert(loadfile(${JSON.stringify(root.bridgePath)}))(); assert(binds==40)
print('PASS: isolated catalog publication, enable/disable, missing/corrupt catalog, held-state reset and observer lifetime')
`);
  const result=spawnSync('luajit',[fixture],{env:{...process.env,XDG_STATE_HOME:dir},encoding:'utf8'});
  assert.equal(result.status,0,result.stdout+result.stderr);
  process.stdout.write(result.stdout);
} finally { fs.rmSync(dir,{recursive:true,force:true}); }
