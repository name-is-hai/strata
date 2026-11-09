// Render the real dialog with a synthetic Polkit backend and harmless process.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const repo = path.resolve(__dirname, '../..');
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'strata-polkit-view-'));
try {
  for (const dir of ['Commons','Ui']) fs.symlinkSync(path.join(repo,'shell',dir),path.join(work,dir));
  let source = fs.readFileSync(path.join(repo,'shell/plugins/polkit/PolkitAgent.qml'),'utf8');
  const agent = /\n  PolkitAgent \{[\s\S]*?\n  \}/;
  assert.match(source,agent);
  source = source.replace(agent, `
  QtObject {
    id: polkitAgent
    property bool isActive: true
    property bool isRegistered: false
    signal authenticationRequestStarted()
    property QtObject flow: QtObject {
      property string message: "Synthetic authorization test"
      property string inputPrompt: ""
      property string supplementaryMessage: "Place your finger on the reader"
      property bool supplementaryIsError: false
      property bool isResponseRequired: false
      property bool responseVisible: false
      property bool failed: false
      property int submissions: 0
      signal authenticationFailed()
      signal authenticationSucceeded()
      signal authenticationRequestCancelled()
      function submit(value) { submissions += 1 }
      function cancelAuthenticationRequest() { throw new Error("Switch cancelled the request") }
    }
  }`);
  source = source.replace('command: ["/usr/share/strata/bin/strata-polkit-use-password"]','command: ["/usr/bin/true"]');
  source = source.replace('command: ["bash", "-c", "strata-hw-laptop-closed && echo closed || echo open"]','command: ["/usr/bin/printf", "open"]');
  // Offscreen Qt has no layer-shell backend; only substitute the window shell.
  source = source.replace('import QtQuick\n','import QtQuick\nimport QtQuick.Window\n')
    .replace('  PanelWindow {','  Window {\n    width: 900; height: 600')
    .replace('    anchors { top: true; bottom: true; left: true; right: true }','')
    .replace(/^    WlrLayershell\..*\n/gm,'')
    .replace('    exclusionMode: ExclusionMode.Ignore','');
  source = source.replace(/\n}\s*$/, `
  function testButton() { return usePasswordButton }
  function testInput() { return passwordInput }
  function testAskPassword() {
    polkitAgent.flow.inputPrompt = "Password:"
    polkitAgent.flow.isResponseRequired = true
  }
  function testSubmissions() { return polkitAgent.flow.submissions }
}`);
  fs.writeFileSync(path.join(work,'PolkitPrompt.qml'),source);
  fs.copyFileSync(path.join(repo,'shell/plugins/polkit/PolkitModel.js'),path.join(work,'PolkitModel.js'));
  fs.writeFileSync(path.join(work,'shell.qml'), `
import QtQuick
import Quickshell
ShellRoot {
  PolkitPrompt { id: prompt }
  function check(value, message) { if (!value) { console.error("FAIL: " + message); Qt.quit() } }
  Timer {
    interval: 300; running: true
    onTriggered: {
      prompt.beginFlow()
      check(prompt.fingerprintMode, "fingerprint mode missing")
      check(prompt.testButton().visible, "Use password button missing")
      check(!prompt.testInput().visible, "password field shown before PAM asks")
      prompt.testButton().clicked()
      check(prompt.switchingToPassword, "button did not request a switch")
      passwordTimer.start()
    }
  }
  Timer {
    id: passwordTimer; interval: 100
    onTriggered: { prompt.testAskPassword(); verifyTimer.start() }
  }
  Timer {
    id: verifyTimer; interval: 100
    onTriggered: {
      check(!prompt.fingerprintMode, "fingerprint mode persisted after password prompt")
      check(!prompt.testButton().visible, "switch button remains in password mode")
      check(prompt.testInput().visible, "password input missing")
      check(prompt.testInput().activeFocus, "password input did not receive focus")
      prompt.testInput().text = "fixture-password"
      prompt.submitResponse()
      check(prompt.testSubmissions() === 1, "normal response was not submitted")
      check(prompt.testInput().text === "", "password was retained after submission")
      console.warn("PASS: real Polkit dialog renders switch button, waits for PAM, focuses password and submits normally")
      Qt.quit()
    }
  }
  Timer { interval:5000; running:true; onTriggered:{console.error("FAIL: timeout");Qt.quit()} }
}`);
  fs.mkdirSync(path.join(work,'runtime'),{mode:0o700});
  const env = {...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software',
    XDG_RUNTIME_DIR:path.join(work,'runtime'),XDG_CACHE_HOME:path.join(work,'cache'),
    DBUS_SYSTEM_BUS_ADDRESS:'unix:path='+path.join(work,'no-system-bus')};
  delete env.WAYLAND_DISPLAY; delete env.HYPRLAND_INSTANCE_SIGNATURE;
  const result = spawnSync('quickshell',['-n','-p',path.join(work,'shell.qml')],{env,encoding:'utf8',timeout:10000});
  const output = result.stdout + result.stderr;
  assert.equal(result.status,0,output);
  assert.ok(!output.includes('FAIL:') && output.includes('PASS: real Polkit dialog'),output);
  console.log('PASS: offscreen Polkit password switch and input focus');
} finally { fs.rmSync(work,{recursive:true,force:true}); }
