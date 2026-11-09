const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const source = fs.readFileSync(path.join(__dirname,'../../shell/plugins/services/idle/LidService.qml'),'utf8');
const queued = [], power = [], errors = [], displays = [];
const state = {action:'system',present:true,stateKnown:false,closed:false,displayOff:false,
  monitorRestarting:false,clamshellSyncPending:false,
  monitorProcess:{running:false},clamshellProcess:{running:false},
  turnDisplayOff(){displays.push('off')},turnDisplayOn(){displays.push('on')},
  requestPowerAction(action){power.push(action)},errorOccurred(message){errors.push(message)},
  Qt:{callLater(fn){queued.push(fn)}}};
state.root=state;
Object.defineProperty(state,'managed',{get(){return state.action!=='system'}});
vm.createContext(state);
for(const name of ['applyState','handleClosed','handleOpened','syncClamshell','clamshellFinished','ensureMonitorRunning'])
  vm.runInContext(source.match(new RegExp('  function '+name+'\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}'))[0],state);
state.ensureMonitorRunning();
assert.equal(state.monitorProcess.running,true,'system-default power handling still observes lid events');
state.applyState(true);
assert.equal(state.clamshellProcess.command.join(' '),'strata-hyprland-monitor-clamshell closed');
assert.deepEqual(power,[],'initial closed state reconciles the monitor without suspending at startup');
state.applyState(false);
assert.equal(state.clamshellSyncPending,true,'opening during a close operation is queued');
state.clamshellProcess.running=false;
state.clamshellFinished(0);
queued.splice(0).forEach(fn=>fn());
assert.equal(state.clamshellProcess.command.join(' '),'strata-hyprland-monitor-clamshell open');
state.clamshellProcess.running=false;
state.action='nothing';state.handleClosed();
assert.deepEqual(power,[],'Do nothing retains its power behavior while reconciling the display');
state.clamshellProcess.running=false;
state.action='display';state.handleClosed();assert.deepEqual(displays,['off']);
state.clamshellProcess.running=false;
state.action='sleep';state.handleClosed();assert.deepEqual(power,['suspend']);
state.present=false;state.monitorProcess.running=true;state.ensureMonitorRunning();
assert.equal(state.monitorProcess.running,false,'desktop without a lid has no watcher');
state.clamshellProcess.running=false;state.syncClamshell();
assert.equal(state.clamshellProcess.running,false);
state.clamshellFinished(1);assert.equal(errors.length,1);
assert.match(source,/onConnectedScreenCountChanged: syncClamshell\(\)/);
// Load the actual QML component with disconnected buses and compositor, so a
// syntax/type regression cannot hide behind the extracted-function tests.
const work=fs.mkdtempSync(path.join(os.tmpdir(),'strata-lid-view-'));
try {
  fs.writeFileSync(path.join(work,'LidLogic.qml'),source);
  fs.mkdirSync(path.join(work,'runtime'),{mode:0o700});
  fs.writeFileSync(path.join(work,'shell.qml'), `
import QtQuick
import Quickshell
ShellRoot {
  LidLogic { id: lid }
  Timer { interval:500; running:true; onTriggered:{console.warn("PASS: lid service QML loaded");Qt.quit()} }
}`);
  const env={...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software',
    XDG_RUNTIME_DIR:path.join(work,'runtime'),XDG_CACHE_HOME:path.join(work,'cache'),
    DBUS_SYSTEM_BUS_ADDRESS:'unix:path='+path.join(work,'no-system-bus')};
  delete env.WAYLAND_DISPLAY;delete env.HYPRLAND_INSTANCE_SIGNATURE;
  const result=spawnSync('quickshell',['-n','-p',path.join(work,'shell.qml')],{env,encoding:'utf8',timeout:5000});
  const output=result.stdout+result.stderr;
  assert.equal(result.status,0,output);
  assert.ok(output.includes('PASS: lid service QML loaded')&&!/ReferenceError|TypeError|SyntaxError/.test(output),output);
} finally {fs.rmSync(work,{recursive:true,force:true});}
console.log('PASS: default/custom lid actions, fresh startup, rapid close/open, no-lid desktop and display topology reconciliation');
