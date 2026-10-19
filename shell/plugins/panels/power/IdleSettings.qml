import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

Column {
  id: root
  property string profile: "balanced"
  property string powerSource: "ac"
  property bool panelOpen: false
  property bool expanded: false
  property bool actionsExpanded: false
  property var bar: null
  property var settings: ({ display: 660, lock: 300, sleep: 1800, hibernate: 0, lid: "system" })
  property bool busy: false
  property bool refreshPending: false
  property int settingsRevision: 0
  property bool lidPresent: false
  property bool hibernateAvailable: false
  property bool suspendThenHibernateAvailable: false
  property string hibernateDiagnostic: ""
  property string errorText: ""
  property int pendingHibernateSeconds: 0
  readonly property string settingsPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/strata/idle-settings.json"
  readonly property color ink: bar ? bar.foreground : Color.foreground
  readonly property string face: bar ? bar.fontFamily : Style.font.family
  readonly property var idleService: bar && bar.shell
    ? bar.shell.firstPartyServiceFor("strata.idle") : null

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(12)

  function refresh() {
    if (!root.panelOpen) return
    if (statusProcess.running || root.busy) {
      root.refreshPending = true
      return
    }
    root.refreshPending = false
    statusProcess.revision = root.settingsRevision
    statusProcess.command = ["strata-idle-settings", "status", root.profile || "balanced", root.powerSource]
    statusProcess.running = true
  }

  function setSetting(field, value) {
    if (root.busy) return
    if ((field === "lid" || field === "powerButton") && root.settings.powerSource !== root.powerSource) return
    if ((field === "lid" || field === "powerButton") && value === "hibernate" && !root.hibernateAvailable) {
      root.errorText = "Hibernate is not available on this computer"
      return
    }
    root.busy = true
    root.settingsRevision += 1
    root.errorText = ""
    if (field === "hibernate") {
      root.pendingHibernateSeconds = Number(value)
      hibernateProcess.command = ["pkexec", "/usr/bin/strata-configure-hibernate", String(value)]
      hibernateProcess.running = true
    } else {
      settingsProcess.command = ["strata-idle-settings", "set", root.profile, field, String(value), root.powerSource]
      settingsProcess.running = true
    }
  }

  function closeActionMenus() {
    if (lidAction) lidAction.close()
    if (powerButtonAction) powerButtonAction.close()
  }

  onProfileChanged: { closeActionMenus(); refresh() }
  onPowerSourceChanged: { closeActionMenus(); refresh() }
  onExpandedChanged: if (!expanded) closeActionMenus()
  onActionsExpandedChanged: if (!actionsExpanded) closeActionMenus()
  onPanelOpenChanged: {
    closeActionMenus()
    if (panelOpen) {
      root.powerSource = UPower.onBattery ? "battery" : "ac"
      root.refresh()
      if (!hibernateProbe.running) hibernateProbe.running = true
    }
  }

  Process {
    id: statusProcess
    property int revision: 0
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(String(text))
          if (root.busy || statusProcess.revision !== root.settingsRevision || result.profile !== root.profile || !result.settings || result.settings.powerSource !== root.powerSource) {
            root.refreshPending = true
            return
          }
          root.settings = result.settings || root.settings
          root.lidPresent = result.lidPresent === true
          root.hibernateAvailable = result.hibernateAvailable === true
          root.suspendThenHibernateAvailable = result.suspendThenHibernateAvailable === true
          root.errorText = ""
        } catch (error) { root.errorText = "Could not read idle settings" }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.errorText = "Could not read idle settings"
      if (root.refreshPending) root.refresh()
    }
  }

  Process {
    id: settingsProcess
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.errorText = "Could not save idle setting"
      root.refresh()
    }
  }

  Process {
    id: hibernateProcess
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.busy = false
        root.errorText = "Could not configure hibernate delay"
        return
      }
      settingsProcess.command = ["strata-idle-settings", "set", root.profile,
        "hibernate", String(root.pendingHibernateSeconds)]
      settingsProcess.running = true
    }
  }

  Process {
    id: hibernateProbe
    command: ["strata-idle-settings", "diagnose-hibernate"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.hibernateDiagnostic = JSON.parse(String(text)).summary || "" }
        catch (error) { root.hibernateDiagnostic = "" }
      }
    }
  }

  FileView {
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
  }

  SettingsCard {
    title: "Screen, sleep & lock"
    description: "Timers for " + root.profile.replace("power-saver", "Power saver") + " mode"
    foreground: root.ink
    fontFamily: root.face
    collapsible: true
    expanded: root.expanded
    onToggleRequested: root.expanded = !root.expanded

    Text {
      width: parent.width
      visible: root.idleService && root.idleService.stayAwake
      text: "Stay Awake is on. Screen-off and sleep timers are paused."
      wrapMode: Text.WordWrap
      color: Util.alpha(root.ink, 0.65)
      font.family: root.face
      font.pixelSize: Style.font.caption
    }
    IdleTimeoutRow {
      title: "Turn off my screens after"
      seconds: Number(root.settings.display || 0)
      presets: [0, 60, 120, 300, 600, 900, 1800]
      busy: root.busy
      foreground: root.ink; fontFamily: root.face
      onChosen: function(seconds) { root.setSetting("display", seconds) }
    }
    PanelSeparator { foreground: root.ink }
    IdleTimeoutRow {
      title: "Put my device to sleep after"
      seconds: Number(root.settings.sleep || 0)
      presets: [0, 900, 1800, 3600, 7200]
      busy: root.busy
      foreground: root.ink; fontFamily: root.face
      onChosen: function(seconds) { root.setSetting("sleep", seconds) }
    }
    PanelSeparator { foreground: root.ink }
    IdleTimeoutRow {
      title: "Lock my device after"
      seconds: Number(root.settings.lock || 0)
      presets: [0, 300, 600, 900, 1800, 3600]
      busy: root.busy
      foreground: root.ink; fontFamily: root.face
      onChosen: function(seconds) { root.setSetting("lock", seconds) }
    }
    PanelSeparator { foreground: root.ink }
    IdleTimeoutRow {
      title: "Hibernate after sleeping"
      detail: root.suspendThenHibernateAvailable ? "Applies to all power modes" : "Unavailable on this device"
      seconds: Number(root.settings.hibernate || 0)
      presets: [0, 1800, 3600, 7200, 14400, 28800]
      busy: root.busy
      available: root.suspendThenHibernateAvailable
      foreground: root.ink; fontFamily: root.face
      onChosen: function(seconds) { root.setSetting("hibernate", seconds) }
    }
    Text {
      width: parent.width
      visible: !root.suspendThenHibernateAvailable && root.hibernateDiagnostic !== ""
      text: root.hibernateDiagnostic
      color: Util.alpha(root.ink, 0.55)
      font.family: root.face
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  SettingsCard {
    title: root.lidPresent ? "Lid & power button" : "Power button"
    description: "Choose what happens on battery or plugged in"
    foreground: root.ink
    fontFamily: root.face
    collapsible: true
    expanded: root.actionsExpanded
    onToggleRequested: root.actionsExpanded = !root.actionsExpanded

    Row {
      width: parent.width
      spacing: Style.space(6)
      Repeater {
        model: [{value: "battery", label: "On battery"}, {value: "ac", label: "Plugged in"}]
        Button {
          required property var modelData
          width: (parent.width - parent.spacing) / 2
          text: modelData.label
          selected: root.powerSource === modelData.value
          enabled: !root.busy
          foreground: root.ink; fontFamily: root.face
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: root.powerSource = modelData.value
        }
      }
    }

    Item {
      width: parent.width
      visible: root.lidPresent
      implicitHeight: Math.max(lidLabel.implicitHeight, lidAction.implicitHeight)
      Text {
        id: lidLabel
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - lidAction.width - Style.space(12)
        text: "When I close the lid"
        color: root.ink
        font.family: root.face; font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }
      Dropdown {
        id: lidAction
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.49
        enabled: !root.busy && root.settings.powerSource === root.powerSource
        label: "Lid close"
        showLabel: false
        value: root.settings.lid || "system"
        updateValueOnSelection: false
        onPopupOpenChanged: if (popupOpen) powerButtonAction.close()
        onEnabledChanged: if (!enabled) close()
        options: [
          {value: "system", label: "System default"},
          {value: "nothing", label: "Do nothing"},
          {value: "display", label: "Display off"},
          {value: "sleep", label: "Sleep"},
          {value: "hibernate", label: root.hibernateAvailable ? "Hibernate" : "Hibernate (unavailable)"}
        ]
        foreground: root.ink; fontFamily: root.face
        onChanged: function(value) { root.setSetting("lid", value) }
      }
    }
    PanelSeparator { visible: root.lidPresent; foreground: root.ink }
    Item {
      width: parent.width
      implicitHeight: Math.max(buttonLabel.implicitHeight, powerButtonAction.implicitHeight)
      Text {
        id: buttonLabel
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - powerButtonAction.width - Style.space(12)
        text: "When I press the power button"
        color: root.ink
        font.family: root.face; font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }
      Dropdown {
        id: powerButtonAction
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.49
        enabled: !root.busy && root.settings.powerSource === root.powerSource
        label: "Power button"
        showLabel: false
        value: root.settings.powerButton || "system"
        updateValueOnSelection: false
        onPopupOpenChanged: if (popupOpen) lidAction.close()
        onEnabledChanged: if (!enabled) close()
        options: [
          {value: "system", label: "System default"},
          {value: "nothing", label: "Do nothing"},
          {value: "menu", label: "Power menu"},
          {value: "lock", label: "Lock"},
          {value: "sleep", label: "Sleep"},
          {value: "hibernate", label: root.hibernateAvailable ? "Hibernate" : "Hibernate (unavailable)"},
          {value: "shutdown", label: "Shut down"}
        ]
        foreground: root.ink; fontFamily: root.face
        onChanged: function(value) { root.setSetting("powerButton", value) }
      }
    }
    Text {
      width: parent.width
      text: "Actions switch with the charger. Power menu is available when unlocked."
      wrapMode: Text.WordWrap
      color: Util.alpha(root.ink, 0.55)
      font.family: root.face; font.pixelSize: Style.font.caption
    }
  }

  Text {
    width: parent.width
    text: root.errorText || (root.idleService ? root.idleService.settingsError : "")
    visible: text !== ""
    wrapMode: Text.WordWrap
    color: Color.urgent
    font.family: root.face; font.pixelSize: Style.font.bodySmall
  }
}
