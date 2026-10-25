// Exercise the production lock binding in Qt with early unlock notification,
// without touching PAM or taking a real session lock.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const source = fs.readFileSync(path.join(__dirname, '../../shell/plugins/lock/Service.qml'), 'utf8');
const binding = source.match(/  readonly property bool locked: (\{[\s\S]*?\n  \})/)[1];
const refresh = source.match(/  function refreshSessionLockState\(\) \{[^\n]+\}/)[0];
for (const signal of ['SecureStateChanged', 'LockStateChanged'])
  assert.match(source, new RegExp('on' + signal + ': \\{\\s*Qt.callLater\\(root.refreshSessionLockState\\)'));
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'strata-lock-state-'));
try {
  const runtime = path.join(work, 'runtime');fs.mkdirSync(runtime, {mode: 0o700});
  fs.writeFileSync(path.join(work, 'shell.qml'), `
import QtQuick
import Quickshell
ShellRoot {
  Item {
    id: root
    property bool lockRequested: false
    // Mutating this object's fields does not notify QML: this reproduces a
    // getter changing after its C++ notification has already been delivered.
    property var sessionLock: ({locked:false, secure:false})
    property int sessionLockRevision: 0
    readonly property bool locked: ${binding}
    ${refresh}
    property int step: 0
    property bool failed: false
    function check(value, message) {
      if (!value) { failed=true; console.error("FAIL: " + message); Qt.quit(); }
    }
    Timer {
      interval: 25; running: true; repeat: true
      onTriggered: {
        if (root.failed) return
        switch (root.step++) {
        case 0:
          root.check(!root.locked, "fresh session is unlocked");
          root.lockRequested=true;
          root.check(root.locked, "pending request suppresses the guide immediately");
          root.sessionLock.locked=true; root.sessionLock.secure=true;
          root.lockRequested=false;
          root.check(root.locked, "active secure lock remains suppressed");
          // The notify callback runs while secure still reads true.
          Qt.callLater(root.refreshSessionLockState);
          root.sessionLock.locked=false; root.sessionLock.secure=false;
          root.check(root.locked, "fixture reproduces the cached stale lock state");
          break;
        case 1:
          root.check(!root.locked, "unlock notification settles to false");
          root.sessionLock.secure=true;
          Qt.callLater(root.refreshSessionLockState);
          break;
        case 2:
          root.check(root.locked, "a still-secure compositor stays suppressed");
          root.sessionLock.secure=false;
          Qt.callLater(root.refreshSessionLockState);
          break;
        case 3:
          root.check(!root.locked, "external unlock also settles to false");
          root.lockRequested=true;
          Qt.callLater(root.refreshSessionLockState);
          break;
        case 4:
          root.check(root.locked, "a new request cannot be cleared by a queued refresh");
          console.warn("PASS: lock state settles after unlock without weakening pending or secure locks");
          Qt.quit();
        }
      }
    }
  }
}
`);
  const env = {...process.env, QT_QPA_PLATFORM:'offscreen', QT_QUICK_BACKEND:'software', XDG_RUNTIME_DIR:runtime};
  delete env.HYPRLAND_INSTANCE_SIGNATURE;delete env.WAYLAND_DISPLAY;
  const result = spawnSync('quickshell', ['-p',work], {env, encoding:'utf8', timeout:10000});
  const output = result.stdout + result.stderr;
  assert.equal(result.status,0,output);
  assert.ok(output.includes('PASS: lock state settles'), output);
  assert.doesNotMatch(output, /FAIL:|Binding loop|ReferenceError|TypeError/);
  console.log('PASS: unlock ordering, pending requests, secure state and repeated lock requests');
} finally {fs.rmSync(work, {recursive:true,force:true});}
