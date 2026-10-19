import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import "../../../Commons/WorkspaceNumbers.js" as Numbers
import qs.Ui

BarWidget {
  id: root
  moduleName: "strata.workspaces"

  readonly property var ownScreen: root.QsWindow.window ? root.QsWindow.window.screen : null
  readonly property var monitor: {
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++)
      if (ownScreen && monitors[i].name === ownScreen.name) return monitors[i]
    return null
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    if (!monitor) return []
    var ids = [1, 2, 3, 4, 5].map(function(n) { return Numbers.base(root.monitor) + n })
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var parked = /^special:strata-desktop-(\d+)$/.exec(values[i].name)
      var id = parked ? Number(parked[1]) : values[i].id
      if (Numbers.owns(monitor, id) && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    if (!monitor) return
    var lua = "__strata_workspaces.select(" + Numbers.number(id) + ", " + JSON.stringify(monitor.name) + ")"
    root.bar.run("hyprctl eval " + Util.shellQuote(lua))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(10) * Style.bar.contentScale
    rowSpacing: root.vertical ? Style.space(2) * Style.bar.contentScale : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: workspaceButton
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (Numbers.number(modelData) === 10 ? "0" : String(Numbers.number(modelData)))
        labelVisible: !focused
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.bar.contentPx(Style.space(20))
        fixedHeight: root.barSize
        OpticalGlyph {
          visible: workspaceButton.focused
          anchors.centerIn: parent
          width: Math.max(1, Math.min(Style.bar.iconSize, parent.width, parent.height))
          height: width
          text: workspaceButton.text
          fontFamily: workspaceButton.fontFamily
          fontSize: Style.bar.iconFont
          targetPaintedExtent: width
          color: workspaceButton.foreground
        }
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
