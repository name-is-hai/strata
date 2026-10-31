// Exercise the shipped greeter's authentication transitions without a live login.
const fs=require('fs'), path=require('path'), vm=require('vm'), assert=require('assert/strict');
const source=fs.readFileSync(path.join(__dirname, '../../defaults/greeter/shell.qml'),'utf8');
function setup() {
 const sent=[];
 const c=vm.createContext({editingUsername:false, fingerprintAvailable:true, fingerprintAttempt:false, passwordSubmitted:false, queuedPassword:'', busy:false, started:false, username:'sotatek', pendingPassword:'', extraPrompt:false, secretPrompt:true, message:'', notice:'', prompt:'Password', bridge:{running:true}, fingerprintRetry:{running:false,restart(){this.running=true},stop(){this.running=false}}, Qt:{quit(){}}, sent});
 for(const m of source.matchAll(/^  function (\w+)\(([^)]*)\) \{([\s\S]*?)^  \}/gm)) vm.runInContext(`function ${m[1]}(${m[2]}) {${m[3]}}`,c);
 c.send=event=>sent.push(event);
 return c;
}
let c=setup(); c.armFingerprint(); assert(c.fingerprintRetry.running); c.startFingerprint(); assert(c.busy && c.fingerprintAttempt); assert.equal(c.sent[0].type,'login'); assert(!('password' in c.sent[0]));
c.handleAuthEvent({type:'notice',message:'Failed to match fingerprint',error:true}); c.handleAuthEvent({type:'prompt',message:'Password:',secret:true}); assert(c.fingerprintRetry.running); assert.equal(c.sent.length,1); c.startFingerprint(); assert.equal(c.sent.length,2);
c=setup(); c.startFingerprint(); c.pendingPassword='typed-password'; c.handleAuthEvent({type:'prompt',message:'Password:',secret:true}); assert(!c.fingerprintRetry.running); assert.equal(c.pendingPassword,'typed-password'); c.submit('typed-password'); assert.equal(c.sent[1].type,'respond'); assert.equal(c.sent[1].response,'typed-password');
c=setup(); c.startFingerprint(); c.submit('queued-password'); assert(c.passwordSubmitted); assert.equal(c.sent.length,1); c.handleAuthEvent({type:'prompt',message:'Password:',secret:true}); assert.equal(c.sent[1].response,'queued-password'); assert.equal(c.queuedPassword,''); assert(c.busy && c.passwordSubmitted); c.handleAuthEvent({type:'error',message:'Wrong password'}); assert(!c.fingerprintRetry.running); assert.equal(c.message,'Wrong password');
c=setup(); c.startFingerprint(); c.handleAuthEvent({type:'error',message:'Scan failed'}); assert(c.fingerprintRetry.running); c.startFingerprint(); c.handleAuthEvent({type:'started'}); assert(c.started); assert(!c.fingerprintRetry.running); c.armFingerprint(); assert(!c.fingerprintRetry.running);
c=setup(); c.fingerprintAvailable=false; c.armFingerprint(); c.startFingerprint(); assert.equal(c.sent.length,0);
c=setup(); c.pendingPassword='in progress'; c.startFingerprint(); assert.equal(c.sent.length,0);
assert(source.includes('authenticatingPassword: root.busy && (!root.fingerprintAttempt || root.passwordSubmitted)'));
assert(!source.includes('onFingerprintLoginRequested'));
c=setup(); c.editingUsername=true; c.armFingerprint(); c.startFingerprint(); assert.equal(c.sent.length,0);
c=setup(); c.startFingerprint(); c.handleAuthEvent({type:'prompt', message:'Public challenge', secret:false}); assert(!c.fingerprintRetry.running);
assert.match(fs.readFileSync(path.join(__dirname, '../../defaults/greeter/config.toml'),'utf8'), /\[general\]\s+service = "strata-greetd"/);
assert.match(fs.readFileSync(path.join(__dirname, '../../packaging/strata-greetd'),'utf8'), /auth\s+sufficient\s+pam_fprintd\.so max-tries=1 timeout=5\s+auth\s+include\s+greetd/);
console.log('PASS: automatic start/retry, no empty password, typing preservation, queued submission, rejection, success and unavailable reader');
