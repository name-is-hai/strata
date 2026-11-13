// Reboot round trips use fresh compositor data, not a cached editor object.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const layout = require('../../shell/plugins/panels/monitor/Layout.js');
const laptop = {name: 'eDP-1', description: 'Laptop panel', width: 1920,
  height: 1080, refreshRate: 120, scale: 1.25, transform: 1, x: -864, y: 120,
  activeWorkspace: {id: 101}};
const raw = JSON.stringify([laptop]);
const initial = layout.parseMonitors(raw);
const docked = layout.parseMonitors(JSON.stringify([laptop, {...laptop,name:'HDMI-A-1',transform:0,x:0,y:0}]));
assert(layout.lidBlocksEnable(docked,0,true,true),'closed lid blocks enabling the laptop with an external display');
assert(!layout.lidBlocksEnable(docked,0,true,false),'opening the lid permits activation');
assert(layout.lidBlocksEnable(docked,0,false,false),'wait for the initial lid query before activation');
assert(!layout.lidBlocksEnable(docked,1,true,true),'external display activation is unaffected');
assert(!layout.lidBlocksEnable([docked[0]],0,true,true),'last-display recovery remains possible');
const dockedOff = layout.setEnabled(docked,0,false);
assert(layout.pendingLidActivation(docked,dockedOff,true,true),'Apply and Save reject a pending re-enable after the lid closes');
assert(!layout.pendingLidActivation(docked,docked,true,true),'an already-active display does not block unrelated layout edits');
assert(!layout.pendingLidActivation(docked,dockedOff,true,false),'pending enable is allowed when open');
const activeConfig = layout.updateConfig('', initial, false);
const disabled = layout.setEnabled(initial, 0, false);
const disabledConfig = layout.updateConfig(activeConfig, disabled, false);
assert.match(disabledConfig, /disabled = true/);
assert.match(disabledConfig, /position = "-864x120"/);
assert.match(disabledConfig, /scale = 1.25/);
assert.match(disabledConfig, /mode = "1920x1080@120"/);
assert.match(disabledConfig, /transform = 1/);
assert(layout.isSaved(disabledConfig, disabled, false));
const rebootRaw = JSON.stringify([{name: 'eDP-1', description: 'Laptop panel',
  disabled: true, width: 0, height: 0, refreshRate: 0, scale: 1,
  transform: 0, x: 0, y: 0}]);
const afterBoot = layout.parseMonitors(rebootRaw, disabledConfig);
for (const field of ['width', 'height', 'refreshRate', 'scale', 'transform', 'x', 'y', 'w', 'h']) {
  assert.equal(afterBoot[0][field], initial[0][field], 'Restores ' + field + ' after reboot');
}
assert.equal(afterBoot[0].disabled, true);
const enabled = layout.setEnabled(afterBoot, 0, true);
const enabledConfig = layout.updateConfig(disabledConfig, enabled, false);
assert.doesNotMatch(enabledConfig, /disabled = true/);
assert(layout.isSaved(enabledConfig, enabled, false));
assert.match(layout.liveScript(disabledConfig, enabled, afterBoot, false), /scale = 1.25/);
assert.match(layout.liveScript(disabledConfig, enabled, afterBoot, false), /position = "-864x120"/);

// First-time saves must preserve the same values without an existing rule.
const firstSave = layout.updateConfig('', disabled, false);
assert.equal(layout.parseMonitors(rebootRaw, firstSave)[0].scale, 1.25);
// Live settings override saved settings for active displays.
assert.equal(layout.parseMonitors(raw, activeConfig.replace('scale = 1.25', 'scale = 2'))[0].scale, 1.25);
assert(!layout.isSaved(activeConfig.replace('scale = 1.25', 'scale = 2'), initial, false),
  'Saved status checks the scale');
// Legacy bare disabled rules have no values to recover, but remain readable.
const legacy = 'hl.monitor({ output = "eDP-1", disabled = true })';
assert.equal(layout.parseMonitors(rebootRaw, legacy)[0].scale, 1);
assert(!layout.isSaved(legacy, afterBoot, false), 'Legacy rule needs a full settings save');
// Preserve hardware identity and unrelated settings when toggling a dock output.
const external = layout.parseMonitors(JSON.stringify([{...laptop, name:'DP-3', description:'Dock display'}]));
const custom = 'hl.monitor({ output = "desc:Dock display", mode = "1920x1080@120", position = "-864x120", scale = 1.25, transform = 1, vrr = 1, bitdepth = 10 })';
const offExternal = layout.updateConfig(custom, layout.setEnabled(external,0,false),false);
assert.match(offExternal, /output = "desc:Dock display"/);
assert.match(offExternal, /vrr = 1, bitdepth = 10/);
const movedPort = JSON.stringify([{name:'DP-5',description:'Dock display',disabled:true}]);
assert.equal(layout.parseMonitors(movedPort,offExternal)[0].x,-864);
// Reading a file never executes Lua expressions as display settings.
const dynamic = activeConfig.replace('scale = 1.25', 'scale = 1 / 2');
assert.equal(layout.parseMonitors(rebootRaw,dynamic)[0].scale,1);
// FileView and hyprctl finish independently. Either load order must restore
// disabled geometry, without overwriting changes the user is still editing.
const panelSource = fs.readFileSync(path.join(__dirname, '../../shell/plugins/panels/monitor/Panel.qml'), 'utf8');
const validateLidActivation = panelSource.match(/  function validateLidActivation\(\) \{[\s\S]*?\n  \}/)[0];
const lidValidation = {Logic:layout, arrangement:docked, live:dockedOff, lidStateKnown:true,
  laptopLidClosed:true, lidDisplaySetting:{disableOnClose:true}, lidBlockedReason:'Lid closed', error:''};
vm.createContext(lidValidation);
vm.runInContext(validateLidActivation,lidValidation);
assert.equal(lidValidation.validateLidActivation(),false,'automatic lid handling blocks re-enabling a closed display');
lidValidation.lidDisplaySetting.disableOnClose=false;
assert.equal(lidValidation.validateLidActivation(),true,'disabling automatic lid handling permits the saved layout');
const rebuild = panelSource.match(/  function rebuild\(rulesJson\) \{[\s\S]*?\n  \}/)[0];
for (const configFirst of [false, true]) {
  const state = {Logic:layout, live:[], arrangement:[], selected:0, pinWorkspaces:false,
    workspaceRulesJson:'', monitorsJson:rebootRaw, configText:configFirst ? disabledConfig : '',
    refreshDisplaySettings(){}};
  Object.defineProperty(state,'changed',{get(){ return !layout.sameLayout(state.arrangement,state.live); }});
  vm.createContext(state);
  vm.runInContext(rebuild,state);
  state.rebuild('');
  if (!configFirst) { state.configText=disabledConfig; state.rebuild(''); }
  assert.equal(state.arrangement[0].scale,1.25,'Restores scale in either load order');
  state.arrangement=layout.setScale(state.arrangement,0,1.5);
  state.rebuild('');
  assert.equal(state.arrangement[0].scale,1.5,'Preserves uncommitted editor changes');
}
console.log('PASS: disabled display reboot/enable round trip, scale status, dock identity, legacy rules and active compositor settings');
