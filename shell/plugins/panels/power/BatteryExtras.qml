import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Battery insights adapted from AROICE-HQ/omarchy-battery (MIT); see
// OMARCHY-BATTERY-LICENSE in this directory. Quick Actions are omitted.
Column {
  id: root
  property var bar: null
  property var batteryInfo: ({})
  property bool panelOpen: false
  property var thresholdInfo: ({})
  property bool thresholdBusy: false
  property string thresholdError: ""
  property real gpuWatts: NaN
  property var impactApps: []
  property var drawSamples: []
  readonly property color ink: bar ? bar.foreground : Color.foreground
  readonly property string face: bar ? bar.fontFamily : Style.font.family

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(12)

  function sampleDraw() {
    if (!panelOpen) return
    var watts = parseFloat(String(batteryInfo.rate || ""))
    if (!isFinite(watts) || watts < 0) return
    var now = Date.now() / 1000
    var next = drawSamples.filter(function(sample) { return sample.t >= now - 600 })
    next.push({ t: now, w: watts })
    drawSamples = next.slice(-121)
  }

  function refresh() {
    if (!panelOpen) return
    if (!thresholdRead.running) thresholdRead.running = true
    if (!gpuRead.running) gpuRead.running = true
    if (!impactRead.running) impactRead.running = true
  }

  function toggleThreshold() {
    if (thresholdBusy || thresholdInfo.supported !== "true") return
    thresholdBusy = true
    thresholdError = ""
    thresholdAction.command = ["strata-battery-threshold",
      thresholdInfo.enabled === "true" ? "disable" : "enable"]
    thresholdAction.running = true
  }

  onPanelOpenChanged: if (panelOpen) {
    sampleDraw()
    refresh()
  }
  onBatteryInfoChanged: sampleDraw()

  Timer {
    interval: 5000
    repeat: true
    running: root.panelOpen
    onTriggered: root.refresh()
  }

  Process {
    id: thresholdRead
    command: ["strata-battery-threshold", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.thresholdInfo = Model.parseKeyValue(text)
    }
  }

  Process {
    id: thresholdAction
    onExited: function(exitCode) {
      root.thresholdBusy = false
      root.thresholdError = exitCode === 0 ? "" : "Could not change charge limit"
      if (!thresholdRead.running) thresholdRead.running = true
    }
  }

  Process {
    id: gpuRead
    command: ["strata-battery-gpu-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = String(text).trim().split(",")
        var watts = parseFloat(parts[0])
        root.gpuWatts = isFinite(watts) ? watts : NaN
      }
    }
  }

  Process {
    id: impactRead
    command: ["strata-battery-power-impact"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var rows = []
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t")
          var cpu = parseFloat(parts[1])
          if (parts.length >= 3 && parts[0] && isFinite(cpu))
            rows.push({ name: parts[0], cpu: cpu, impact: parts[2] })
        }
        root.impactApps = rows
      }
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(9)
    Item {
      width: parent.width
      implicitHeight: Math.max(drawHeading.implicitHeight, drawValue.implicitHeight)
      PanelSectionHeader {
        id: drawHeading
        text: "Power draw"
        foreground: root.ink
        fontFamily: root.face
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        id: drawValue
        anchors.right: parent.right
        width: Math.max(0, parent.width - drawHeading.implicitWidth - Style.space(12))
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        text: "BATTERY " + (root.batteryInfo.rate || "—")
          + (isFinite(root.gpuWatts) ? "  ·  GPU " + root.gpuWatts.toFixed(1) + "W" : "")
        color: root.ink
        opacity: 0.8
        font.family: root.face
        font.pixelSize: Style.font.bodySmall
      }
    }
    Rectangle {
      width: parent.width
      height: Style.space(62)
      color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.035)
      border.width: 1
      border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
      Canvas {
        id: sparkline
        anchors.fill: parent
        anchors.margins: Style.space(4)
        onWidthChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var samples = root.drawSamples
          if (!samples.length) return
          var maximum = 1
          for (var i = 0; i < samples.length; i++) maximum = Math.max(maximum, samples[i].w)
          var span = Math.max(1, samples[samples.length - 1].t - samples[0].t)
          var floor = height - Style.space(3)
          ctx.beginPath()
          for (var j = 0; j < samples.length; j++) {
            var x = samples.length === 1 ? 0 : (samples[j].t - samples[0].t) / span * width
            var y = Style.space(3) + (1 - samples[j].w / maximum) * (height - Style.space(6))
            if (j === 0) ctx.moveTo(x, y)
            else ctx.lineTo(x, y)
          }
          if (samples.length === 1) ctx.lineTo(width, floor)
          ctx.strokeStyle = root.ink
          ctx.lineWidth = 1.5
          ctx.stroke()
          ctx.lineTo(width, height)
          ctx.lineTo(0, height)
          ctx.closePath()
          ctx.fillStyle = Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.13)
          ctx.fill()
        }
        Connections {
          target: root
          function onDrawSamplesChanged() { sparkline.requestPaint() }
        }
      }
    }
  }

}
