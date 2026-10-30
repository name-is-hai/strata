// Real Qt file-watcher lifecycle, without a compositor, PAM or session lock.
const fs=require('node:fs'), os=require('node:os'), path=require('node:path');
const assert=require('node:assert/strict'), vm=require('node:vm');
const {spawnSync}=require('node:child_process');
const repo=path.resolve(__dirname,'../..');
const screens={}; vm.runInNewContext(fs.readFileSync(path.join(repo,'shell/plugins/lock/ScreenSelection.js'),'utf8'),screens);
const outputs=[{name:'HDMI-A-1',x:0,y:0,width:2560,height:1440},{name:'hypr-rdp-1',x:-9999,y:0,width:1920,height:1080}];
assert.equal(screens.formScreenName(outputs), 'HDMI-A-1');
assert.equal(screens.formScreenName(outputs,true), 'hypr-rdp-1','remote client gets the actual password form');
assert.equal(screens.formScreenName(outputs.slice(0,1),true), 'HDMI-A-1');
const source=fs.readFileSync(path.join(repo,'shell/plugins/services/idle/Service.qml'),'utf8');
const watcher=source.match(/  FileView \{\n    id: remoteDesktopState[\s\S]*?\n  \}/)[0];
const polling=source.match(/  Timer \{\n    interval: 1000[\s\S]*?onTriggered: remoteDesktopState.reload\(\)\n  \}/)[0];
const work=fs.mkdtempSync(path.join(os.tmpdir(),'strata-rdp-state-'));
try {
  const runtime=path.join(work,'runtime'); fs.mkdirSync(runtime,{mode:0o700});
  fs.writeFileSync(path.join(work,'shell.qml'),`
import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
  Item {
    id: root
    property bool remoteDesktopActive: false
    property int step: 0
    property int ticks: 0
    ${watcher}
    ${polling}
    Process { id: writer }
    Timer {
      interval: 100; running: true; repeat: true
      onTriggered: {
        if (++root.ticks > 70) { console.error("FAIL: state watcher timed out at " + root.step); Qt.quit(); return }
        var file=Quickshell.env("XDG_RUNTIME_DIR") + "/strata-remote-desktop/active"
        if (root.step === 0) {
          if (root.remoteDesktopActive) { console.error("FAIL: missing marker is active"); Qt.quit(); return }
          writer.command=["bash","-c",'mkdir -p "$(dirname "$1")"; printf "%s\\n" "$2" >"$1"',"test",file,"test-instance"]
          writer.running=true; root.step=1
        } else if (root.step === 1 && root.remoteDesktopActive && !writer.running) {
          writer.command=["bash","-c",'printf "%s\\n" "other-instance" >"$1"',"test",file]
          writer.running=true; root.step=2
        } else if (root.step === 2 && !root.remoteDesktopActive && !writer.running) {
          writer.command=["bash","-c",'printf "%s\\n" "test-instance" >"$1"',"test",file]
          writer.running=true; root.step=3
        } else if (root.step === 3 && root.remoteDesktopActive && !writer.running) {
          writer.command=["rm",file]; writer.running=true; root.step=4
        } else if (root.step === 4 && !root.remoteDesktopActive && !writer.running) {
          console.warn("PASS: missing directory, marker creation, session mismatch, reconnect and removal"); Qt.quit()
        }
      }
    }
  }
}`);
  const env={...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software',QML_DISABLE_DISK_CACHE:'1',XDG_RUNTIME_DIR:runtime,HYPRLAND_INSTANCE_SIGNATURE:'test-instance'};
  delete env.WAYLAND_DISPLAY;
  const r=spawnSync('quickshell',['-n','-p',path.join(work,'shell.qml')],{env,encoding:'utf8',timeout:12000});
  const output=r.stdout+r.stderr;
  assert.equal(r.status,0,output);
  assert.ok(output.includes('PASS: missing directory')&&!output.includes('FAIL:'),output);
  console.log('PASS: actual Qt remote marker lifecycle and local/remote lock form selection');
} finally {fs.rmSync(work,{recursive:true,force:true});}
