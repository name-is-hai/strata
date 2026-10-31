// Run the real PAM-message handler without authenticating or locking a session.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../../shell/plugins/lock/Service.qml'), 'utf8');
const handler = source.match(/  function handleFingerprintMessage\([^)]*\) \{[\s\S]*?\n  \}/)[0];
const state = {lockRequested:true, fingerprintNotice:'', reached:0, failedAttempts:0,
  failureMessage:'', noteFingerprintReachedDevice(){ state.reached++; }};
vm.createContext(state);
vm.runInContext(handler,state);
state.handleFingerprintMessage('Place your finger on the reader',false);
assert.equal(state.fingerprintNotice,'Place your finger on the reader');
assert.equal(state.reached,1);
state.handleFingerprintMessage('Failed to match fingerprint',true);
assert.equal(state.fingerprintNotice,'Failed to match fingerprint');
assert.equal(state.reached,1,'A scan error does not establish reader reachability');
assert.equal(state.failedAttempts,0,'Fingerprint feedback does not count as a password failure');
assert.equal(state.failureMessage,'');
state.handleFingerprintMessage('Try again',false);
assert.equal(state.fingerprintNotice,'Try again');
state.lockRequested=false;
state.fingerprintNotice='';
state.handleFingerprintMessage('Late scan message',true);
assert.equal(state.fingerprintNotice,'','Late PAM feedback stays hidden after unlock');
assert.match(source,/fingerprintNotice = ""/);
assert.match(source,/authenticationNotice: root.lockRequested && root.fingerprintConfigured\s+&& !root.fingerprintUnavailable && !root.authenticatingPassword/);
console.log('PASS: lock fingerprint instructions, mismatch/retry feedback, late-message suppression and independent password errors');
