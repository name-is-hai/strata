import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "strata.indicators"

  readonly property var defaultIndicatorEntries: [ "ScreenRecording", "NightLight", "Dnd", "StayAwake" ]
  readonly property var indicatorEntries: indicatorEntriesFromSettings(settings)
  // The owning ModuleSlot is the exact hit area for this widget.
  property bool slotHovered: false
  property string slotRegion: ""
  readonly property bool alwaysShowIndicators: setting("alwaysShow", false) === true
  readonly property bool revealInactiveIndicators: alwaysShowIndicators || slotHovered
  property var indicatorActiveStates: ({})
  readonly property var activeIndicatorIds: orderedIndicatorIds(true)
  readonly property var inactiveIndicatorIds: orderedIndicatorIds(false)
  readonly property int activeCount: activeIndicatorIds.length
  readonly property bool expandBackwards: slotRegion === "right"
  readonly property int visibleSlotCount: revealInactiveIndicators
    ? indicatorEntries.length : Math.max(1, activeCount)

  clip: true
  onIndicatorEntriesChanged: {
    var next = {}
    for (var i = 0; i < indicatorEntries.length; i++) {
      var id = entryId(indicatorEntries[i])
      if (indicatorActiveStates && indicatorActiveStates[id] === true) next[id] = true
    }
    indicatorActiveStates = next
  }

  signal refreshRequested()

  function entryId(entry) {
    if (typeof entry === "string") return entry
    if (Util.isPlainObject(entry)) {
      var id = entry["id"]
      if (id !== undefined && id !== null && String(id) !== "") return String(id)
    }
    return ""
  }

  function entrySettings(entry) {
    if (!Util.isPlainObject(entry)) return {}
    var copy = {}
    for (var key in entry) {
      if (key === "id") continue
      copy[key] = entry[key]
    }
    return copy
  }

  function indicatorEntriesFromSettings(settings) {
    var source = defaultIndicatorEntries
    if (settings.items && typeof settings.items.length === "number" && settings.items.length > 0) source = settings.items
    else if (settings.indicators && typeof settings.indicators.length === "number" && settings.indicators.length > 0) source = settings.indicators

    var result = []
    for (var i = 0; i < source.length; i++) {
      var item = source[i]
      if (typeof item !== "string" && item !== null && typeof item === "object") {
        try {
          item = JSON.parse(JSON.stringify(item))
        } catch (error) {
        }
      }
      if (entryId(item) !== "") result.push(item)
    }
    return result
  }

  function orderedIndicatorIds(active) {
    var ids = []
    for (var i = 0; i < indicatorEntries.length; i++) {
      var id = entryId(indicatorEntries[i])
      if ((indicatorActiveStates[id] === true) === active) ids.push(id)
    }
    return ids
  }

  function setIndicatorActive(id, active) {
    if (!id || (indicatorActiveStates[id] === true) === active) return
    var next = {}
    for (var key in indicatorActiveStates) {
      if (indicatorActiveStates[key] === true) next[key] = true
    }
    if (active) next[id] = true
    else delete next[id]
    indicatorActiveStates = next
  }

  function indicatorRank(id) {
    var activeIndex = activeIndicatorIds.indexOf(id)
    var inactiveIndex = inactiveIndicatorIds.indexOf(id)
    if (expandBackwards && revealInactiveIndicators)
      return activeIndex >= 0 ? inactiveIndicatorIds.length + activeIndex : inactiveIndex
    return activeIndex >= 0 ? activeIndex : activeIndicatorIds.length + inactiveIndex
  }

  // Collapsed: one slot per active status. Expanded: one slot per configured
  // status. A single empty slot provides a discoverable hover target when
  // nothing is active.
  implicitWidth: vertical ? barSize : visibleSlotCount * Style.bar.statusSlot
  implicitHeight: vertical ? visibleSlotCount * Style.bar.statusSlot : barSize

  function debugIndicatorSlots() {
    var slots = []
    for (var i = 0; i < indicatorRepeater.count; i++) {
      var item = indicatorRepeater.itemAt(i)
      slots.push(item ? item.debugState() : { missing: true })
    }
    return slots
  }

  ShellIpc {
    target: "strata.indicators"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Component.onCompleted: root.refreshRequested()

  Repeater {
    id: indicatorRepeater
    model: root.indicatorEntries

    IndicatorLoader {
      required property var modelData
      entry: modelData
    }
  }

  component IndicatorLoader: Item {
    id: indicatorSlot

    required property var entry
    readonly property string indicatorId: root.entryId(entry)
    readonly property var indicatorSettings: root.entrySettings(entry)
    readonly property var barRef: root.bar

    implicitWidth: root.vertical ? root.barSize : Style.bar.statusSlot
    implicitHeight: root.vertical ? Style.bar.statusSlot : root.barSize
    width: implicitWidth
    height: implicitHeight
    x: root.vertical ? 0 : root.indicatorRank(indicatorId) * width
    y: root.vertical ? root.indicatorRank(indicatorId) * height : 0
    visible: root.revealInactiveIndicators || root.indicatorActiveStates[indicatorId] === true
    onEntryChanged: {
      injectProps()
      syncActiveState()
    }
    onIndicatorSettingsChanged: injectProps()
    onBarRefChanged: injectProps()

    function debugState() {
      var item = indicatorSource.item
      return {
        id: indicatorId,
        width: width,
        implicitWidth: implicitWidth,
        x: x,
        y: y,
        loaderStatus: indicatorSource.status,
        loaded: !!item,
        visible: item ? item.visible : false,
        targetWidth: item ? item.implicitWidth : 0,
        active: item ? item.active : false,
        text: item ? item.text : ""
      }
    }

    Loader {
      id: indicatorSource
      anchors.fill: parent
      source: indicatorSlot.indicatorId ? Qt.resolvedUrl("../indicators/" + indicatorSlot.indicatorId + ".qml") : ""
      onLoaded: {
        indicatorSlot.injectProps()
        indicatorSlot.syncActiveState()
      }
      onStatusChanged: if (status === Loader.Error) console.warn("Indicator loader error", indicatorSlot.indicatorId, source)
    }

    Connections {
      target: indicatorSource.item
      ignoreUnknownSignals: true
      function onActiveChanged() { indicatorSlot.syncActiveState() }
    }

    function injectProps() {
      var target = indicatorSource.item
      if (!target) return
      if ("bar" in target) target.bar = root.bar
      if ("moduleName" in target) target.moduleName = indicatorId
      if ("settings" in target) target.settings = indicatorSettings
      if ("indicatorBlock" in target) target.indicatorBlock = "single"
      if ("indicatorHost" in target) target.indicatorHost = root
      if ("activeOverride" in target) target.activeOverride = null
    }

    function syncActiveState() {
      if (indicatorId) root.setIndicatorActive(indicatorId,
        !!indicatorSource.item && indicatorSource.item.active === true)
    }
  }
}
