#!/bin/bash
# Verify image readiness and crop geometry without displaying anything.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
repo=$(cd "$here/../../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -m 700 "$work/runtime"
ln -s "$repo/shell/Commons" "$work/Commons"
magick -size 600x200 xc:black "$work/original.png"
magick "$work/original.png" -thumbnail '100x100>' "$work/preview.jpg"
cat > "$work/shell.qml" <<'QML'
import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot {
 property var frame:null
 property var initialGeometry:null
 property int step:0
 property int attempts:0
 Window { id: window; width:640; height:360; visible:true }
 Timer { interval:50; repeat:true; running:true; onTriggered:{
  attempts++
  if(attempts>100){console.error("FAIL: framing test timed out");Qt.quit();return}
  if(!frame){
   var component=Qt.createComponent("file://"+Quickshell.env("FRAME_TEST_REPO")+"/shell/plugins/background/WallpaperFrame.qml")
   if(component.status!==Component.Ready){console.error("FAIL: "+component.errorString());Qt.quit();return}
   frame=component.createObject(window.contentItem,{width:640,height:360,path:Quickshell.env("FRAME_TEST_WORK")+"/original.png",decodeSize:Qt.size(640,360),nativeSize:{width:600,height:200,pending:true},placement:{mode:"fill",x:0.34,y:0,zoom:1.22}})
   if(!frame){console.error("FAIL: cannot create frame");Qt.quit();return}
  }
  if(frame.status!==Image.Ready)return
  if(step===0){
   if(frame.ready){console.error("FAIL: image revealed before native geometry ready");Qt.quit();return}
   frame.nativeSize={width:600,height:200,pending:false}
   step=1
  }else if(step===1){
   if(!frame.ready)return
   initialGeometry=JSON.stringify(frame.geometry)
   frame.path=Quickshell.env("FRAME_TEST_WORK")+"/preview.jpg"
   step=2
  }else{
   if(!frame.ready)return
   if(JSON.stringify(frame.geometry)!==initialGeometry){console.error("FAIL: preview and desktop crop differ");Qt.quit();return}
   console.warn("PASS: saved crop matches before/after handoff; header readiness gates display")
   frame.destroy();Qt.quit()
  }
 }}
}
QML
env QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$work/runtime" FRAME_TEST_REPO="$repo" FRAME_TEST_WORK="$work" \
  quickshell -p "$work/shell.qml" > "$work/log" 2>&1
if rg -q 'FAIL:' "$work/log" || ! rg -q 'PASS: saved crop' "$work/log"; then cat "$work/log"; exit 1; fi
echo 'PASS: preview/desktop crop geometry and native-size readiness'
