import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Sounds.js" as Sounds

// "System sounds" at the bottom of the Audio panel: the master switch, the
// volume, the sound theme, and a switch and preview per event.
//
// The Audio panel loads this file straight from the plugin folder and lends it
// its keyboard cursor (see the contract below). Everything shown comes from
// `strata-sounds state`, and every change goes back through the same command,
// so the panel, the CLI and the shell service never disagree.
//
// Cursor rows, top to bottom:
//   -1                       volume slider (Enter or m: all sounds on/off)
//   0                        "<desktop theme> sounds", only if that theme ships some
//   themeExpanderIndex       "Sound theme": show or hide the theme list
//   themeBase ..             one row per sound theme, while shown (Enter: use it)
//   expanderIndex            "Events": show or hide the per-event switches
//   eventBase ..             one row per event, while shown (Enter: on/off, l or p: preview)
//   customizeIndex           open the folder where your own sounds go
Column {
  id: section

  // ---- Set by the Audio panel
  property var bar: null
  property bool open: false
  property int cursorIndex: -2          // -2 while the panel cursor is elsewhere

  signal cursorRequested(int index)
  signal revealRequested(var item)
  signal closeRequested()

  // ---- Read by the Audio panel
  readonly property bool hasSlider: true
  readonly property int rowCount: customizeIndex + 1

  readonly property string cli: Sounds.localPath(Qt.resolvedUrl("bin/strata-sounds"))
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: Style.hoverFillFor(foreground, Color.accent)
  readonly property color selectedFill: Style.selectedFillFor(foreground, Color.accent)

  // The last `strata-sounds state`, and what was changed since, so a click
  // shows at once instead of after the round trip.
  property var model: null
  property var pending: ({})
  property bool themesExpanded: false
  property bool expanded: false

  readonly property bool soundsOn: pending.enabled !== undefined ? pending.enabled : (model ? model.enabled : true)
  readonly property string theme: pending.theme !== undefined ? pending.theme : (model ? model.theme : "")
  readonly property int volume: pending.volume !== undefined ? pending.volume : (model ? model.volume : 80)
  readonly property bool themeSounds: pending.themeSounds !== undefined ? pending.themeSounds : (model ? model.useThemeSounds : true)
  readonly property var themes: model ? model.themes : []
  readonly property var events: model ? model.events.filter(function(e) { return e.available }) : []
  readonly property bool hasDesktopRow: !!(model && model.desktopTheme && model.desktopTheme.hasSounds)

  readonly property int themeExpanderIndex: hasDesktopRow ? 1 : 0
  readonly property int themeBase: themeExpanderIndex + 1
  readonly property int expanderIndex: themeBase + (themesExpanded ? themes.length : 0)
  readonly property int eventBase: expanderIndex + 1
  readonly property int customizeIndex: eventBase + (expanded ? events.length : 0)

  readonly property int eventsOn: {
    var n = 0
    for (var i = 0; i < events.length; i++) if (eventIsOn(events[i])) n++
    return n
  }

  spacing: Style.space(6)

  function eventIsOn(event) {
    var overrides = pending.events
    return overrides && overrides[event.id] !== undefined ? overrides[event.id] : event.on
  }

  function themeLabel(id) {
    for (var i = 0; i < themes.length; i++) if (themes[i].id === id) return themes[i].label
    return id
  }

  function eventTip(event) {
    var lines = []
    if (event.trigger) lines.push(event.trigger + ".")
    if (event.windows) lines.push("Windows: " + event.windows)
    if (!event.file) {
      lines.push("No sound for this in " + themeLabel(theme))
    } else {
      var origin = event.origin || {}
      var where = origin.kind === "desktop" ? model.desktopTheme.label + " desktop theme"
        : origin.kind === "user" ? "your " + themeLabel(origin.theme) + " folder"
        : themeLabel(origin.theme)
      lines.push(event.file.split("/").pop() + " from " + where)
    }
    return lines.join("\n")
  }

  // ------------------------------------------------------------- actions

  function remember(change) {
    pending = Object.assign({}, pending, change)
  }

  function toggleSounds() {
    var next = !soundsOn
    remember({ enabled: next })
    run([next ? "on" : "off"])
  }

  function toggleThemeSounds() {
    var next = !themeSounds
    remember({ themeSounds: next })
    run(["theme-sounds", next ? "on" : "off"])
  }

  function chooseTheme(entry) {
    if (!entry) return
    remember({ theme: entry.id })
    if (entry.id !== (model ? model.theme : "")) run(["set", entry.id])
    run(["preview", "notification"])
  }

  function toggleEvent(event) {
    if (!event) return
    var next = !eventIsOn(event)
    var overrides = Object.assign({}, pending.events || {})
    overrides[event.id] = next
    remember({ events: overrides })
    run([next ? "on" : "off", event.id])
  }

  function preview(id) {
    run(["preview", id])
  }

  // The write waits for the slider to settle; the preview follows it so you
  // hear the new level, the way Windows rings when you let go of its slider.
  function setVolume(value) {
    remember({ volume: Math.max(0, Math.min(100, Math.round(value))) })
    volumeWrite.restart()
  }

  function customize() {
    Quickshell.execDetached([cli, "edit"])
    closeRequested()
  }

  // ------------------------------------------------- the panel's cursor

  function activate(index) {
    if (index === -1) toggleSounds()
    else if (hasDesktopRow && index === 0) toggleThemeSounds()
    else if (index === themeExpanderIndex) themesExpanded = !themesExpanded
    else if (index < expanderIndex) chooseTheme(themes[index - themeBase])
    else if (index === expanderIndex) expanded = !expanded
    else if (index < customizeIndex) toggleEvent(events[index - eventBase])
    else if (index === customizeIndex) customize()
  }

  function adjust(index, delta) {
    if (index === -1) setVolume(volume + Math.round(delta * 100))
    else if (index === themeExpanderIndex) themesExpanded = delta > 0
    else if (index === expanderIndex) expanded = delta > 0
    else if (index >= eventBase && index < customizeIndex && delta > 0) preview(events[index - eventBase].id)
  }

  function textKey(text, index) {
    var key = String(text).toLowerCase()
    if (key === "m") {
      toggleSounds()
      return true
    }
    if (key === "p") {
      if (index >= eventBase && index < customizeIndex) preview(events[index - eventBase].id)
      else preview("notification")
      return true
    }
    return false
  }

  // -------------------------------------------------------- the command

  property var queue: []
  property bool wrote: false
  property bool readAgain: false

  // Writes run one at a time and in order; previews start as soon as the
  // writes queued before them have finished. After the last write, re-read.
  function run(args) {
    queue = queue.concat([args])
    pump()
  }

  function pump() {
    while (!writer.running && queue.length > 0) {
      var next = queue[0]
      queue = queue.slice(1)
      if (next[0] === "preview") {
        Quickshell.execDetached([cli].concat(next))
      } else {
        wrote = true
        writer.command = [cli].concat(next)
        writer.running = true
      }
    }
    if (!writer.running && queue.length === 0 && wrote) {
      wrote = false
      refresh()
    }
  }

  function refresh() {
    if (reader.running) readAgain = true
    else reader.running = true
  }

  onOpenChanged: if (open) refresh()
  Component.onCompleted: if (open) refresh()

  Process {
    id: writer
    onExited: section.pump()
  }

  Process {
    id: reader
    command: [section.cli, "state"]
    stdout: StdioCollector { id: readerOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        try {
          section.model = JSON.parse(readerOut.text)
          if (!writer.running && section.queue.length === 0 && !section.readAgain) section.pending = ({})
        } catch (e) {
          console.warn("system-sounds: unreadable state: " + e)
        }
      }
      if (section.readAgain) {
        section.readAgain = false
        reader.running = true
      }
    }
  }

  Timer {
    id: volumeWrite
    interval: 250
    onTriggered: {
      section.run(["volume", String(section.volume)])
      section.run(["preview", "bell"])
    }
  }

  // ---------------------------------------------------------------- header

  Item {
    width: parent.width
    implicitHeight: Math.max(header.implicitHeight, masterSwitch.implicitHeight)

    PanelSectionHeader {
      id: header
      text: "SYSTEM SOUNDS"
      foreground: section.foreground
      fontFamily: section.fontFamily
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      textFormat: Text.PlainText
      text: Math.round(slider.dragging ? slider.liveValue : section.volume) + "%"
      color: Qt.darker(section.foreground, 1.4)
      font.family: section.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      opacity: section.soundsOn ? 1 : 0.5
      anchors.right: masterSwitch.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
    }

    ToggleSwitch {
      id: masterSwitch
      checked: section.soundsOn
      cursorRing: false
      trackHeight: Math.max(16, Math.round(Style.spacing.controlHeight * 0.55))
      foreground: section.foreground
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      onToggled: section.toggleSounds()

      PanelToolTip {
        visible: masterSwitch.containsMouse
        text: section.soundsOn ? "Turn system sounds off" : "Turn system sounds on"
        fontFamily: section.fontFamily
      }
    }
  }

  CursorSurface {
    id: sliderRow
    width: parent.width
    height: slider.implicitHeight + Style.spacing.controlGap
    hasCursor: section.cursorIndex === -1
    onHasCursorChanged: if (hasCursor) section.revealRequested(sliderRow)
    foreground: section.foreground
    outline: true

    ScrollSafeSlider {
      id: slider
      bar: section.bar
      anchors.fill: parent
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      minimum: 0
      maximum: 100
      step: 5
      integer: true
      value: section.volume
      opacity: section.soundsOn ? 1 : 0.5

      onReleased: function(v) { section.setVolume(v) }
      onRightClicked: section.toggleSounds()
    }

    HoverHandler {
      onHoveredChanged: if (hovered) section.cursorRequested(-1)
    }
  }

  // ------------------------------------------------------------ themes

  Item {
    width: parent.width
    height: desktopRow.visible ? desktopRow.implicitHeight : 0
    visible: section.hasDesktopRow

    SwitchRow {
      id: desktopRow
      width: parent.width
      rowIndex: 0
      glyph: "󰏘"
      label: (section.model ? section.model.desktopTheme.label : "") + " theme sounds"
      checked: section.themeSounds
      tip: "Sounds your desktop theme ships in its sounds/ folder, played ahead of the sound theme"
      onActivated: section.toggleThemeSounds()
    }
  }

  PlainRow {
    width: parent.width
    rowIndex: section.themeExpanderIndex
    glyph: section.themesExpanded ? "󰅀" : "󰅂"
    label: "Sound theme"
    detail: section.themeLabel(section.theme)
    onActivated: section.themesExpanded = !section.themesExpanded
  }

  Repeater {
    model: section.themesExpanded ? section.themes : []

    ThemeRow {
      required property var modelData
      required property int index
      width: section.width
      entry: modelData
      rowIndex: section.themeBase + index
    }
  }

  // ------------------------------------------------------------ events

  PlainRow {
    width: parent.width
    rowIndex: section.expanderIndex
    glyph: section.expanded ? "󰅀" : "󰅂"
    label: "Events"
    detail: section.eventsOn + " of " + section.events.length + " on"
    onActivated: section.expanded = !section.expanded
  }

  Repeater {
    model: section.expanded ? section.events : []

    EventRow {
      required property var modelData
      required property int index
      width: section.width
      event: modelData
      rowIndex: section.eventBase + index
    }
  }

  PlainRow {
    width: parent.width
    rowIndex: section.customizeIndex
    glyph: "󰉋"
    label: "Add your own sounds…"
    tip: "Opens your " + section.themeLabel(section.theme) + " folder in ~/.config/strata/sounds.\n"
      + "A file named after an event (bell.ogg, device-added.wav, …) replaces that sound."
    onActivated: section.customize()
  }

  // ----------------------------------------------------------- rows

  component PlainRow: CursorSurface {
    id: plainRow
    property int rowIndex: 0
    property string glyph: ""
    property string label: ""
    property string detail: ""
    property string tip: ""
    signal activated()

    hasCursor: section.cursorIndex === rowIndex
    onHasCursorChanged: if (hasCursor) section.revealRequested(plainRow)
    foreground: section.foreground
    fill: section.hoverFill
    implicitHeight: plainInner.implicitHeight + Style.spacing.xl

    Row {
      id: plainInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: plainRow.glyph
        color: section.foreground
        font.family: section.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: plainRow.label
        color: section.foreground
        font.family: section.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        width: parent.width - Style.space(30) - plainDetail.width - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: plainDetail
        textFormat: Text.PlainText
        text: plainRow.detail
        color: Qt.darker(section.foreground, 1.5)
        font.family: section.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    HoverHandler {
      id: plainHover
      onHoveredChanged: if (hovered) section.cursorRequested(plainRow.rowIndex)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: plainRow.activated()
    }

    PanelToolTip {
      visible: plainHover.hovered && plainRow.tip !== ""
      text: plainRow.tip
      fontFamily: section.fontFamily
    }
  }

  component SwitchRow: CursorSurface {
    id: switchRow
    property int rowIndex: 0
    property string glyph: ""
    property string label: ""
    property string tip: ""
    property bool checked: false
    signal activated()

    hasCursor: section.cursorIndex === rowIndex
    onHasCursorChanged: if (hasCursor) section.revealRequested(switchRow)
    foreground: section.foreground
    fill: section.hoverFill
    implicitHeight: switchInner.implicitHeight + Style.spacing.xl

    Row {
      id: switchInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: switchRow.glyph
        color: section.foreground
        font.family: section.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: switchRow.label
        color: section.foreground
        font.family: section.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        width: parent.width - Style.space(30) - switchToggle.width - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }

      ToggleSwitch {
        id: switchToggle
        checked: switchRow.checked
        interactive: false
        trackHeight: Math.max(14, Math.round(Style.spacing.controlHeight * 0.5))
        foreground: section.foreground
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    HoverHandler {
      id: switchHover
      onHoveredChanged: if (hovered) section.cursorRequested(switchRow.rowIndex)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: switchRow.activated()
    }

    PanelToolTip {
      visible: switchHover.hovered && switchRow.tip !== ""
      text: switchRow.tip
      fontFamily: section.fontFamily
    }
  }

  // A sound theme. Picking one plays its notification sound as a sample.
  component ThemeRow: CursorSurface {
    id: themeRow
    property var entry: ({})
    property int rowIndex: 0
    readonly property bool isActive: entry.id === section.theme
    readonly property string tag: entry.source === "user" ? "custom" : (entry.overlaid ? "edited" : "")

    hasCursor: section.cursorIndex === rowIndex
    onHasCursorChanged: if (hasCursor) section.revealRequested(themeRow)
    current: isActive
    foreground: section.foreground
    fill: section.hoverFill
    currentFill: section.selectedFill
    opacity: section.soundsOn ? 1 : 0.5
    implicitHeight: themeInner.implicitHeight + Style.spacing.lg

    Row {
      id: themeInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(16)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: "󰝚"
        color: section.foreground
        font.family: section.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(18)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: themeRow.entry.label || themeRow.entry.id || ""
        color: section.foreground
        font.family: section.fontFamily
        font.pixelSize: Style.font.body
        font.bold: themeRow.isActive
        elide: Text.ElideRight
        width: parent.width - Style.space(26) - themeTag.width - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: themeTag
        textFormat: Text.PlainText
        text: themeRow.tag
        color: Qt.darker(section.foreground, 1.5)
        font.family: section.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    HoverHandler {
      id: themeHover
      onHoveredChanged: if (hovered) section.cursorRequested(themeRow.rowIndex)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: section.chooseTheme(themeRow.entry)
    }

    PanelToolTip {
      visible: themeHover.hovered && !!themeRow.entry.comment
      text: themeRow.entry.comment || ""
      fontFamily: section.fontFamily
    }
  }

  // One event: click the row to switch it, click ▶ to hear it.
  component EventRow: CursorSurface {
    id: eventRow
    property var event: ({})
    property int rowIndex: 0
    readonly property bool on: section.eventIsOn(event)

    hasCursor: section.cursorIndex === rowIndex
    onHasCursorChanged: if (hasCursor) section.revealRequested(eventRow)
    foreground: section.foreground
    fill: section.hoverFill
    opacity: section.soundsOn ? 1 : 0.5
    implicitHeight: eventInner.implicitHeight + Style.spacing.lg

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: section.toggleEvent(eventRow.event)
    }

    Row {
      id: eventInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(16)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: eventRow.event.glyph || ""
        color: section.foreground
        opacity: eventRow.on ? 1 : 0.45
        font.family: section.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(18)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: eventRow.event.label || eventRow.event.id || ""
        color: section.foreground
        opacity: eventRow.on ? 1 : 0.55
        font.family: section.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        width: parent.width - Style.space(26) - playButton.width - eventToggle.width - Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: playButton
        textFormat: Text.PlainText
        text: "󰐊"
        color: section.foreground
        opacity: playMouse.containsMouse ? 1 : (eventRow.hasCursor ? 0.75 : 0.35)
        font.family: section.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
          id: playMouse
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: section.preview(eventRow.event.id)
        }
      }

      ToggleSwitch {
        id: eventToggle
        checked: eventRow.on
        interactive: false
        trackHeight: Math.max(14, Math.round(Style.spacing.controlHeight * 0.5))
        foreground: section.foreground
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    HoverHandler {
      id: eventHover
      onHoveredChanged: if (hovered) section.cursorRequested(eventRow.rowIndex)
    }

    PanelToolTip {
      visible: eventHover.hovered && !playMouse.containsMouse
      text: section.eventTip(eventRow.event)
      fontFamily: section.fontFamily
    }
  }
}
