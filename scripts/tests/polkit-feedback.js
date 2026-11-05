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
const state = {polkitAgent:{flow}, PolkitModel, passwordInput:{text:''}};
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
assert.match(source,/text: root.currentSupplementary/);
assert.match(source,/color: root.supplementaryIsError \? Color.polkit.textError/);
assert.doesNotMatch(source,/path: "\/etc\/pam.d\/polkit-1"/);
for (const text of ['No devices available','User liam has no fingers enrolled','No fingerprints enrolled']) {
  assert.equal(FingerprintModel.classifyProbe(text),'no');
  assert.equal(PolkitModel.visibleSupplementary(text),'');
}
assert.equal(FingerprintModel.classifyProbe('yes'),'yes');
assert.equal(FingerprintModel.classifyProbe('unknown'),'unknown');
const lock = fs.readFileSync(path.join(__dirname,'../../shell/plugins/lock/Service.qml'),'utf8');
assert.match(lock,/readonly property bool fingerprintUnavailable: fingerprintConfigured &&/);
console.log('PASS: scan instructions, visible mismatch errors, password fallback, absent enrollment and cleared feedback');
