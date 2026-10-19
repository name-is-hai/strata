import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "ServiceModel.js" as Model
import "Promoter.js" as Promoter

Item {
  id: root

  readonly property string moduleName: "strata.shortcut-guide"
  property var shell: null
  property var manifest: null
  property var promotedBinds: []
  property bool promoterRefreshPending: false
  property bool promoterEnabled: true
  signal bindingMatched(string bindingId)

  property bool guideEnabled: true
  readonly property string integrationState: guideEnabled ? "enabled" : "disabled"
  property bool integrationStateKnown: true
  property var integrationDetails: ({})
  property var catalog: null
  property bool guideVisible: false
  property bool captureActive: false
  property string activeModifiers: ""
  property string activeGuideRoot: ""
  property string highlightedBindingId: ""
  property int guideDelayMs: 500
  property int guideTopOffset: 0
  property bool showInFullscreen: false
  property bool guideSuperEnabled: true
  property bool guideShiftEnabled: false
  property bool guideCtrlEnabled: false
  property bool guideAltEnabled: false
  // Suppression starts active until both independent sources have answered.
  // Unknown state must never briefly expose the guide over a protected surface.
  property bool desktopLocked: true
  property bool lockStateKnown: false
  property bool credentialPromptActive: true
  property bool credentialPromptStateKnown: false
  property bool activeWindowFullscreen: false
  onActiveWindowFullscreenChanged: if (activeWindowFullscreen && !showInFullscreen) promoter.hide()
  property bool guideAwaitingLockCheck: false
  property bool lockStatusRefreshPending: false
  property bool lockStatusTimedOut: false
  property bool layerStatusTimedOut: false
  property bool layerRefreshPending: false
  property int layerEventRevision: 0
  property int layerRequestRevision: 0

  property string catalogState: "loading"
  property bool catalogPublicationPending: false
  property var pendingCatalogGeneration: null
  property string deferredBridgeReloadSourceHash: ""
  property string activeBridgeReloadSourceHash: ""
  property string pendingBridgeReloadSourceHash: ""
  property string lastBridgeReloadSourceHash: ""
  property string manualSnippet: ""
  property string lastProtocolError: ""
  property int bridgeEventCount: 0
  property var sessionDiagnostics: ({
    catalogLoadFailures: 0,
    integrationFailures: 0,
    fullscreenQueryCount: 0,
    fullscreenQueryFailures: 0,
    lockQueryFailures: 0,
    layerQueryFailures: 0
  })

  // These diagnostics remain intentionally in memory only. They are useful to
  // the feasibility IPC target and do not become a statistics implementation.
  property double pendingGuideReceivedMs: 0
  property int observedEventCount: 0
  property var latencySamples: []

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  readonly property string stateDir: stateHome + "/strata/shortcut-guide"

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = decodeURIComponent(value.substring(7))
    return value
  }

  readonly property string generatorPath: localPath(Qt.resolvedUrl("scripts/generate-catalog"))
  function protocolPayload(event) {
    if (!event || String(event.name || "") !== "custom") return ""
    var payload = String(event.data || "")
    return payload.indexOf("strata-shortcuts:") === 0 ? payload : ""
  }

  function setDiagnostic(name, delta) {
    var next = {}
    for (var key in sessionDiagnostics) next[key] = sessionDiagnostics[key]
    next[name] = Number(next[name] || 0) + Number(delta || 1)
    sessionDiagnostics = next
  }

  function handleProtocolEvent(payload) {
    bridgeEventCount += 1
    observedEventCount += 1
    var parsed = Model.parseProtocol(payload, root.catalog)
    if (!guideEnabled) return false
    if (!parsed.ok) {
      lastProtocolError = parsed.error
      return false
    }

    lastProtocolError = ""
    if (parsed.type === "guide") {
      if (parsed.phase === "down") {
        if (captureActive || capturePending.running) { root.clearGuide(); return true }
        if (!root.guideRootEnabled(parsed.root)) {
          root.clearGuide()
          return true
        }
        pendingGuideReceivedMs = Date.now()
        activeGuideRoot = parsed.root
        activeModifiers = parsed.root
        highlightedBindingId = ""
        guideVisible = false
        guideAwaitingLockCheck = true
        root.requestLockStatus(true)
      } else {
        root.clearGuide()
      }
      return true
    }
    if (parsed.type === "mods") {
      if (guideVisible || guideAwaitingLockCheck) activeModifiers = parsed.modifiers
      return true
    }
    if (parsed.type === "match") {
      if (!parsed.known) {
        lastProtocolError = "unknown-binding-id"
        return false
      }
      highlightedBindingId = parsed.id
      bindingMatched(parsed.id)
      return true
    }
    return false
  }

  function recordGuideVisible() {
    if (pendingGuideReceivedMs <= 0) return
    var next = latencySamples.slice()
    next.push(Math.max(0, Date.now() - pendingGuideReceivedMs))
    latencySamples = next
    pendingGuideReceivedMs = 0
  }

  function resetDiagnostics() {
    clearGuide()
    observedEventCount = 0
    bridgeEventCount = 0
    latencySamples = []
    lastProtocolError = ""
  }

  function diagnosticsJson() {
    return JSON.stringify({
      eventCount: observedEventCount,
      bridgeEventCount: bridgeEventCount,
      sampleCount: latencySamples.length,
      samplesMs: latencySamples,
      guideVisible: guideVisible,
      captureActive: captureActive,
      capturePending: capturePending.running,
      catalogState: catalogState,
      integrationState: integrationState,
      lastProtocolError: lastProtocolError,
      sessionDiagnostics: sessionDiagnostics
    })
  }

  function loadCatalog(raw) {
    var result = Model.normalizeCatalog(raw)
    if (!result.ok) {
      catalog = null
      catalogState = "error"
      setDiagnostic("catalogLoadFailures", 1)
      return false
    }
    catalog = result.catalog
    catalogState = "ready"
    return true
  }

  function bindingForId(id) {
    var key = String(id || "")
    return catalog && catalog.byId ? (catalog.byId[key] || null) : null
  }

  function openGuide() { guideVisible = true }
  function closeGuide() { guideVisible = false }

  property var localSettings: ({})
  readonly property string settingsPath: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/strata/shortcut-guide.json"

  function syncSettings() {
    const previous = guideEnabled
    const entry = localSettings || {}
    guideEnabled = entry.enabled !== false
    guideDelayMs = entry.guideDelayMs === undefined ? 500 : Model.normalizeDelay(entry.guideDelayMs)
    guideTopOffset = Model.normalizeTopOffset(entry.guideTopOffset)
    showInFullscreen = entry.showInFullscreen === true
    guideSuperEnabled = entry.guideSuperEnabled !== false
    guideShiftEnabled = entry.guideShiftEnabled === true
    guideCtrlEnabled = entry.guideCtrlEnabled === true
    guideAltEnabled = entry.guideAltEnabled === true
    promoterEnabled = entry.promoterEnabled !== false
    promoter.position = ["center", "bottom-center", "bottom-right"].indexOf(entry.promoterPosition) >= 0
      ? entry.promoterPosition : "center"
    if (!guideEnabled || !promoterEnabled) promoter.hide()
    if (!guideEnabled || !guideRootEnabled(activeGuideRoot)) clearGuide()
    if (previous !== guideEnabled) { regenerateCatalog(); promoterRefreshTimer.restart() }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        const parsed = JSON.parse(text())
        if (Model.isObject(parsed)) root.localSettings = parsed
      } catch (error) { console.warn("Shortcut Guide: invalid settings:", error) }
      root.syncSettings()
    }
    onLoadFailed: { root.localSettings = ({}); root.syncSettings() }
  }

  function guideRootEnabled(rootName) {
    if (rootName === "SUPER") return guideSuperEnabled
    if (rootName === "SHIFT") return guideShiftEnabled
    if (rootName === "CTRL") return guideCtrlEnabled
    if (rootName === "ALT") return guideAltEnabled
    return false
  }

  function clearGuide() {
    guideVisible = false
    guideAwaitingLockCheck = false
    activeModifiers = ""
    activeGuideRoot = ""
    highlightedBindingId = ""
    pendingGuideReceivedMs = 0
  }

  function suppressGuide() {
    promoter.hide()
    if (guideVisible || guideAwaitingLockCheck) clearGuide()
  }

  function evaluatePendingGuide() {
    if (!guideAwaitingLockCheck) return false
    if (!lockStateKnown || !credentialPromptStateKnown) return false
    if (desktopLocked || credentialPromptActive || captureActive || capturePending.running) {
      clearGuide()
      return false
    }
    guideAwaitingLockCheck = false
    guideVisible = true
    return true
  }

  function setLockStateUnknown() {
    lockStateKnown = false
    desktopLocked = true
    suppressGuide()
  }

  function recordLockStatus(raw, exitCode) {
    var parsed = Model.parseLockStatus(raw, exitCode)
    if (!parsed.ok) {
      setDiagnostic("lockQueryFailures", 1)
      setLockStateUnknown()
      return false
    }
    lockStateKnown = true
    desktopLocked = parsed.locked
    if (desktopLocked) suppressGuide()
    else evaluatePendingGuide()
    return true
  }

  function requestLockStatus(forGuide) {
    if (lockStatusProcess.running) {
      if (forGuide === true) lockStatusRefreshPending = true
      return false
    }
    lockStatusTimeoutTimer.restart()
    lockStatusProcess.running = true
    return true
  }

  function requestLayerStatus() {
    if (layerStatusProcess.running) {
      layerRefreshPending = true
      return false
    }
    layerStatusDebounceTimer.restart()
    return true
  }

  function handlePolkitLayerEvent(name, data) {
    if (!Model.isPolkitLayerEvent(name, data)) return false
    layerEventRevision += 1
    if (name === "openlayer") {
      credentialPromptStateKnown = true
      credentialPromptActive = true
    } else {
      // Keep the guide hidden until a fresh inventory confirms that every
      // Strata Polkit surface has closed, including on multi-monitor setups.
      credentialPromptStateKnown = false
      credentialPromptActive = true
    }
    suppressGuide()
    requestLayerStatus()
    return true
  }

  function recordLayerStatus(raw, exitCode) {
    if (layerRequestRevision !== layerEventRevision) {
      requestLayerStatus()
      return false
    }
    var parsed = Model.parseLayerStatus(raw, exitCode)
    if (!parsed.ok) {
      credentialPromptStateKnown = false
      credentialPromptActive = true
      setDiagnostic("layerQueryFailures", 1)
      suppressGuide()
      return false
    }
    credentialPromptStateKnown = true
    credentialPromptActive = parsed.active
    captureActive = parsed.captureActive === true
    if (credentialPromptActive || captureActive) suppressGuide()
    else evaluatePendingGuide()
    return true
  }

  function recordFullscreenResult(raw, exitCode) {
    var next = {}
    for (var key in sessionDiagnostics) next[key] = sessionDiagnostics[key]
    next.fullscreenQueryCount = Number(next.fullscreenQueryCount || 0) + 1
    sessionDiagnostics = next
    if (exitCode !== 0) {
      setDiagnostic("fullscreenQueryFailures", 1)
      return false
    }
    var parsed = Model.parseActiveWindow(raw)
    if (!parsed.ok) {
      setDiagnostic("fullscreenQueryFailures", 1)
      return false
    }
    activeWindowFullscreen = parsed.fullscreen
    return true
  }

  property bool fullscreenQueryPending: false

  function requestFullscreenRefresh() {
    fullscreenQueryPending = true
    fullscreenQueryTimer.restart()
  }

  function handleRawEvent(event) {
    if (!event) return
    var name = String(event.name || "")
    var data = String(event.data || "")
    if ((name === "openlayer" || name === "closelayer") && data.trim() === "strata-snip") {
      root.captureActive = true
      root.layerEventRevision += 1
      root.suppressGuide()
      root.requestLayerStatus()
      return
    }
    if (name === "configreloaded") promoterRefreshTimer.restart()
    if (handlePolkitLayerEvent(name, data)) return
    if (name === "custom") {
      var payload = protocolPayload(event)
      if (payload !== "") handleProtocolEvent(payload)
      return
    }
    if (Model.isCatalogChangeEvent(name)) catalogChangeTimer.restart()
    if (Model.isFullscreenEvent(name)) requestFullscreenRefresh()
  }

  Timer {
    id: catalogChangeTimer
    interval: 350
    repeat: false
    onTriggered: root.regenerateCatalog()
  }

  property bool catalogRegenerationPending: false
  property string generatorOutput: ""

  function scheduleBridgeReloadForChangedCatalog(sourceHash) {
    return requestCatalogBridgeReload(sourceHash)
  }

  function requestCatalogBridgeReload(sourceHash) {
    var generation = { ok: true, sourceHash: String(sourceHash || ""), changed: true }
    if (catalogBridgeReloadProcess.running) {
      if (generation.sourceHash === activeBridgeReloadSourceHash) {
        pendingBridgeReloadSourceHash = ""
        return false
      }
      pendingBridgeReloadSourceHash = generation.sourceHash
      return true
    }
    if (!Model.shouldReloadCatalogBridge(
          generation,
          "enabled",
          lastBridgeReloadSourceHash,
          activeBridgeReloadSourceHash,
          pendingBridgeReloadSourceHash)) return false
    activeBridgeReloadSourceHash = generation.sourceHash
    catalogBridgeReloadProcess.command = ["hyprctl", "reload"]
    catalogBridgeReloadProcess.running = true
    return true
  }

  function completeCatalogPublication(loaded) {
    var generation = pendingCatalogGeneration
    pendingCatalogGeneration = null
    catalogPublicationPending = false
    if (loaded && generation) {
      if (catalogBridgeReloadProcess.running) {
        pendingBridgeReloadSourceHash = Model.pendingBridgeReloadAfterCatalog(
              generation.sourceHash,
              activeBridgeReloadSourceHash)
      } else if (generation.changed) {
        scheduleBridgeReloadForChangedCatalog(generation.sourceHash)
      }
    }
    if (catalogRegenerationPending) {
      catalogRegenerationPending = false
      catalogChangeTimer.restart()
    }
  }

  function regenerateCatalog() {
    if (catalogGenerationProcess.running || catalogPublicationPending) {
      catalogRegenerationPending = true
      return false
    }
    if (generatorPath === "") return false
    catalogRegenerationPending = false
    catalogGenerationProcess.command = ["python3", generatorPath, "--output-dir", stateDir].concat(guideEnabled ? [] : ["--disabled"])
    catalogGenerationProcess.running = true
    return true
  }

  FileView {
    id: catalogFile
    path: root.stateDir + "/catalog.json"
    watchChanges: false
    printErrors: false
    onLoaded: {
      var publicationPending = root.catalogPublicationPending
      var loaded = root.loadCatalog(text())
      if (publicationPending) root.completeCatalogPublication(loaded)
    }
    onLoadFailed: {
      if (!root.catalogPublicationPending) return
      root.catalog = null
      root.catalogState = "error"
      root.setDiagnostic("catalogLoadFailures", 1)
      if (root.catalogPublicationPending) root.completeCatalogPublication(false)
    }
  }

  Process {
    id: catalogGenerationProcess
    running: false
    stdout: StdioCollector { id: generatorStdout; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      root.generatorOutput = String(generatorStdout.text || "")
      var generated = Model.parseCatalogGeneration(root.generatorOutput, exitCode)
      if (!generated.ok) {
        root.catalogState = "error"
        root.setDiagnostic("catalogLoadFailures", 1)
        if (root.catalogRegenerationPending) {
          root.catalogRegenerationPending = false
          catalogChangeTimer.restart()
        }
        return
      }
      root.pendingCatalogGeneration = generated
      root.catalogPublicationPending = true
      catalogFile.reload()
    }
  }

  Process {
    id: catalogBridgeReloadProcess
    running: false
    onExited: function(exitCode, exitStatus) {
      var completedHash = root.activeBridgeReloadSourceHash
      root.activeBridgeReloadSourceHash = ""
      if (exitCode === 0) root.lastBridgeReloadSourceHash = completedHash
      else root.setDiagnostic("integrationFailures", 1)

      if (root.pendingBridgeReloadSourceHash !== "") {
        var pendingHash = root.pendingBridgeReloadSourceHash
        root.pendingBridgeReloadSourceHash = ""
        Qt.callLater(function() { root.requestCatalogBridgeReload(pendingHash) })
      }
    }
  }

  Timer {
    id: fullscreenQueryTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (!root.fullscreenQueryPending || fullscreenQueryProcess.running) return
      root.fullscreenQueryPending = false
      fullscreenQueryProcess.running = true
    }
  }

  Process {
    id: fullscreenQueryProcess
    command: ["hyprctl", "-j", "activewindow"]
    running: false
    stdout: StdioCollector { id: fullscreenStdout; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      root.recordFullscreenResult(fullscreenStdout.text, exitCode)
      if (root.fullscreenQueryPending) fullscreenQueryTimer.restart()
    }
  }

  Timer {
    id: lockStatusTimeoutTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (!lockStatusProcess.running) return
      root.lockStatusTimedOut = true
      root.setDiagnostic("lockQueryFailures", 1)
      root.setLockStateUnknown()
      lockStatusProcess.signal(9)
    }
  }

  Timer {
    id: lockStatusRetryTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      if (!root.lockStateKnown && !lockStatusProcess.running)
        root.requestLockStatus(false)
    }
  }

  Timer {
    id: visibleLockRefreshTimer
    interval: 100
    repeat: true
    running: root.guideVisible || promoter.opened
    onTriggered: root.requestLockStatus(false)
  }

  Process {
    id: lockStatusProcess
    command: ["strata-shell", "lock", "isLocked"]
    running: false
    stdout: StdioCollector { id: lockStatusStdout; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      lockStatusTimeoutTimer.stop()
      if (root.lockStatusTimedOut) {
        root.lockStatusTimedOut = false
        if (root.lockStatusRefreshPending) {
          root.lockStatusRefreshPending = false
          Qt.callLater(function() { root.requestLockStatus(false) })
        }
        return
      }
      if (root.lockStatusRefreshPending) {
        root.lockStatusRefreshPending = false
        Qt.callLater(function() { root.requestLockStatus(false) })
        return
      }
      root.recordLockStatus(lockStatusStdout.text, exitCode)
    }
  }

  Timer {
    id: layerStatusDebounceTimer
    interval: 40
    repeat: false
    onTriggered: {
      if (layerStatusProcess.running) {
        root.layerRefreshPending = true
        return
      }
      root.layerRefreshPending = false
      root.layerRequestRevision = root.layerEventRevision
      root.layerStatusTimedOut = false
      layerStatusTimeoutTimer.restart()
      layerStatusProcess.running = true
    }
  }

  Timer {
    id: layerStatusRetryTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      if ((!root.credentialPromptStateKnown || root.credentialPromptActive)
          && !layerStatusProcess.running)
        root.requestLayerStatus()
    }
  }

  Timer {
    id: layerStatusTimeoutTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (!layerStatusProcess.running) return
      root.layerStatusTimedOut = true
      root.credentialPromptStateKnown = false
      root.credentialPromptActive = true
      root.setDiagnostic("layerQueryFailures", 1)
      root.suppressGuide()
      layerStatusProcess.signal(9)
    }
  }

  Process {
    id: layerStatusProcess
    command: ["hyprctl", "-j", "layers"]
    running: false
    stdout: StdioCollector { id: layerStatusStdout; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      layerStatusTimeoutTimer.stop()
      if (root.layerStatusTimedOut) {
        root.layerStatusTimedOut = false
        if (root.layerRefreshPending) {
          root.layerRefreshPending = false
          Qt.callLater(function() { root.requestLayerStatus() })
        }
        return
      }
      if (root.layerRequestRevision !== root.layerEventRevision) {
        root.layerRefreshPending = false
        Qt.callLater(function() { root.requestLayerStatus() })
        return
      }
      root.recordLayerStatus(layerStatusStdout.text, exitCode)
      if (root.layerRefreshPending) {
        root.layerRefreshPending = false
        Qt.callLater(function() { root.requestLayerStatus() })
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.handleRawEvent(event) }
  }

  Connections {
    target: root.shell
    ignoreUnknownSignals: true
    function onBarConfigChanged() { root.syncSettings() }
  }

  ShellIpc {
    target: "shortcut-guide"
    function status(): string { return root.integrationState }
    function diagnostics(): string { return root.diagnosticsJson() }
    function reset(): string { root.resetDiagnostics(); return "ok" }
    function promote(payloadJson: string): string { return root.promoteSelection(payloadJson) }
    function prepareCapture(): string { return root.prepareCapture() }
  }

  Component.onCompleted: Qt.callLater(function() {
    root.syncSettings()
    root.regenerateCatalog()
    root.requestFullscreenRefresh()
    root.requestLockStatus(false)
    root.requestLayerStatus()
    promoterRefreshTimer.restart()
  })

  onShellChanged: Qt.callLater(function() {
    root.syncSettings()
  })

  Guide {
    id: desktopGuide
    service: root
  }

  function promoteSelection(payloadJson) {
    if (!guideEnabled || !promoterEnabled || captureActive || capturePending.running || !lockStateKnown || desktopLocked
        || !credentialPromptStateKnown || credentialPromptActive
        || (!showInFullscreen && activeWindowFullscreen)) return ""
    var selection
    try { selection = JSON.parse(payloadJson) } catch (error) { return "" }
    var bind = null
    if (selection.command) bind = Promoter.matchAction(promotedBinds, selection.command)
    else if (selection.appId) {
      const id = String(selection.appId).replace(/\.desktop$/, "")
      const values = DesktopEntries.applications.values
      const entry = values.find(e => String(e.id).replace(/\.desktop$/, "") === id)
      bind = Promoter.matchWindow(promotedBinds, id, entry)
    }
    if (!bind) return ""
    promoter.show(bind.combo, bind.description, 0)
    return bind.combo
  }

  Timer {
    id: promoterRefreshTimer
    interval: 350
    onTriggered: {
      if (!root.guideEnabled) return
      if (promoterBindsProcess.running) root.promoterRefreshPending = true
      else promoterBindsProcess.running = true
    }
  }

  Process {
    id: promoterBindsProcess
    command: ["strata-menu-keybindings", "--json"]
    stdout: StdioCollector { id: promoterBindsOutput; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) {
        try { root.promotedBinds = Promoter.prepare(JSON.parse(promoterBindsOutput.text)) }
        catch (error) { root.promotedBinds = [] }
      }
      if (root.promoterRefreshPending) {
        root.promoterRefreshPending = false
        promoterRefreshTimer.restart()
      }
    }
  }

  PromoterToast {
    id: promoter
    shell: root.shell
    showCount: false
  }

  function prepareCapture() {
    desktopGuide.prepareCapture()
    clearGuide()
    promoter.hideImmediately()
    capturePending.restart()
    return "ok"
  }

  Timer {
    id: capturePending
    interval: 1500
  }
}
