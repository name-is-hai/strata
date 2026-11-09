// Exercise production flow snapshots without authenticating or registering an agent.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const PolkitModel = require('../../shell/plugins/polkit/PolkitModel.js');
const FingerprintModel = require('../../shell/plugins/lock/FingerprintModel.js');
const source = fs.readFileSync(path.join(__dirname, '../../shell/plugins/polkit/PolkitAgent.qml'), 'utf8');
const flow = {message:'Authorize test', inputPrompt:'', supplementaryMessage:'', supplementaryIsError:false,
  isResponseRequired:false, responseVisible:false, failed:false};
const state = {polkitAgent:{flow}, PolkitModel, passwordInput:{text:''}, flowGeneration:0,
  passwordSwitchTimer:{stop(){}}};
vm.createContext(state);
for (const name of ['syncFromFlow','resetSnapshot']) {
  vm.runInContext(source.match(new RegExp('  function '+name+'\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}'))[0], state);
}
flow.supplementaryMessage='Place your right index finger on the reader';
state.syncFromFlow();
assert.equal(state.fingerprintConfigured,true);
assert.equal(state.supplementaryIsError,false);
flow.supplementaryMessage='Failed to match fingerprint';
flow.supplementaryIsError=true;
state.syncFromFlow();
assert.equal(state.fingerprintConfigured,true,'a mismatch keeps fingerprint mode available');
assert.equal(state.currentSupplementary,'Failed to match fingerprint');
assert.equal(state.supplementaryIsError,true);
flow.isResponseRequired=true;
flow.inputPrompt='Password:';
state.syncFromFlow();
assert.equal(state.fingerprintConfigured,false,'PAM password prompt switches to password mode');
flow.supplementaryMessage='No fingerprints enrolled';
state.syncFromFlow();
assert.equal(state.currentSupplementary,'');
state.resetSnapshot();
assert.equal(state.supplementaryIsError,false);
assert.equal(state.currentSupplementary,'');
assert.equal(state.fingerprintConfigured,false);
assert.match(source,/onSupplementaryIsErrorChanged/);
assert.match(source,/text: root.passwordSwitchError \|\| root.currentSupplementary/);
assert.match(source,/root.supplementaryIsError \? Color.polkit.textError/);
assert.doesNotMatch(source,/path: "\/etc\/pam.d\/polkit-1"/);
for (const text of ['No devices available','User liam has no fingers enrolled','No fingerprints enrolled']) {
  assert.equal(FingerprintModel.classifyProbe(text),'no');
  assert.equal(PolkitModel.visibleSupplementary(text),'');
}
assert.equal(FingerprintModel.classifyProbe('yes'),'yes');
assert.equal(FingerprintModel.classifyProbe('unknown'),'unknown');
const lock = fs.readFileSync(path.join(__dirname,'../../shell/plugins/lock/Service.qml'),'utf8');
assert.match(lock,/readonly property bool fingerprintUnavailable: fingerprintConfigured &&/);
Object.assign(state,{fingerprintMode:true,switchingToPassword:false,dialogVisible:true,responseRequired:false,
  passwordSwitchProcess:{running:false},passwordSwitchTimer:{restarts:0,restart(){this.restarts++},stop(){}}});
for (const name of ['usePassword','passwordSwitchFinished']) {
  vm.runInContext(source.match(new RegExp('  function '+name+'\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}'))[0], state);
}
state.usePassword();
assert.equal(state.passwordSwitchProcess.running,true);
assert.equal(state.switchingToPassword,true);
assert.equal(state.passwordSwitchProcess.generation,state.flowGeneration);
state.passwordSwitchFinished(state.flowGeneration,0);
assert.equal(state.passwordSwitchTimer.restarts,1);
state.passwordSwitchFinished(state.flowGeneration-1,1);
assert.equal(state.passwordSwitchError,'','late completion cannot affect another authorization');
state.passwordSwitchFinished(state.flowGeneration,1);
assert.match(state.passwordSwitchError,/Could not stop/);
state.responseRequired=true;
state.passwordSwitchFinished(state.flowGeneration,1);
flow.isResponseRequired=true; state.syncFromFlow();
assert.equal(state.switchingToPassword,false);
assert.equal(state.passwordSwitchError,'');
assert.equal(state.passwordInput.text,'','switching does not submit or retain a password');
assert.doesNotMatch(source.match(/  function usePassword\([\s\S]*?\n  \}/)[0],/cancelAuthenticationRequest|submit\(/);
console.log('PASS: scan instructions, visible mismatch errors, password fallback, absent enrollment and cleared feedback');
