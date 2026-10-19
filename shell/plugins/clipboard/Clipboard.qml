import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "ClipboardHistory.js" as ClipboardHistory
import "ClipboardPlacement.js" as ClipboardPlacement

Item {
  id: root

  property string strataPath: Quickshell.env("STRATA_PATH")
  property bool opened: false
  property bool openPending: false
  property var popupPosition: null
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property bool clearConfirmOpen: false
  property var history: []

  property string historyPath: Quickshell.env("HOME") + "/.local/state/strata/clipboard-history.json"
  property string captureScript: root.strataPath + "/shell/plugins/clipboard/capture.sh"
  // Shares the [menu] surface tokens — themes that style the menu also
  // style the clipboard. Selected-row colors composed in the
  // singleton so consumers drop them straight into Rectangle bindings.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  // Keep the compact picker geometry consistent across theme panel padding.
  property int contentMargin: Style.space(12)
  readonly property int listPaintInset: Math.max(1, Style.normalBorderWidth)
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.max(1, Math.min(Style.space(320), panel.width - Style.gapsOut * 2))
  property int cardHeight: Math.max(1, Math.min(Style.space(410), panel.height - Style.gapsOut * 2))
  property int rowHeight: Math.max(Style.space(50), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property int historyLimit: 500

  function open(payloadJson) {
    root.openPending = true
    if (!positionProc.running) positionProc.running = true
  }

  function showAtCursor(raw) {
    if (!root.openPending) return
    root.openPending = false
    root.popupPosition = ClipboardPlacement.parsePosition(raw)
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
    root.opened = true
    if (root.popupPosition) {
      for (var i = 0; i < Quickshell.screens.length; i++) {
        if (Quickshell.screens[i].name === root.popupPosition.name) {
          panel.targetScreen = Quickshell.screens[i]
          break
        }
      }
    }
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.openPending = false
    root.cancelClearHistory()
    root.opened = false
  }

  function toggle() {
    if (root.opened || root.openPending) root.close()
    else root.open("{}")
  }

  function normalizeEntry(value) {
    return ClipboardHistory.normalizeEntry(value)
  }

  function entryKey(entry) {
    return ClipboardHistory.entryKey(entry)
  }

  function loadHistory(raw) {
    root.history = ClipboardHistory.parseHistory(raw)
    if (root.opened) root.rebuildDisplay()
  }

  function saveHistory() {
    historyFile.setText(JSON.stringify(ClipboardHistory.trimHistory(root.history, root.historyLimit), null, 2) + "\n")
  }

  function addClipboardEntry(entry) {
    var normalized = ClipboardHistory.normalizeEntry(entry)
    if (!normalized) return

    root.history = ClipboardHistory.addEntry(root.history, normalized, root.historyLimit)
    root.saveHistory()
    if (root.opened) root.rebuildDisplay()
  }

  function addClipboardJson(line) {
    root.addClipboardEntry(ClipboardHistory.parseEntryJson(line))
  }

  function requestClearHistory() {
    if (root.history.length === 0) return
    clearConfirm.selectedIndex = 1
    root.clearConfirmOpen = true
  }

  function cancelClearHistory() {
    root.clearConfirmOpen = false
    root.disarmPointer()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmClearHistory() {
    root.history = ClipboardHistory.clearHistory(root.history)
    root.saveHistory()
    root.selectedIndex = 0
    root.cursorActive = false
    root.disarmPointer()
    root.clearConfirmOpen = false
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function removeDisplayIndex(index) {
    if (index < 0 || index >= displayModel.count) return

    var row = displayModel.get(index)
    root.history = ClipboardHistory.removeEntryAt(root.history, row.historyIndex)
    root.saveHistory()

    if (displayModel.count <= 1) {
      root.selectedIndex = 0
      root.cursorActive = false
    } else if (root.selectedIndex >= displayModel.count - 1) {
      root.selectedIndex = displayModel.count - 2
    }

    root.disarmPointer()
    root.rebuildDisplay()
  }

  function togglePinIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var historyIndex = displayModel.get(index).historyIndex
    root.history = ClipboardHistory.togglePinAt(root.history, historyIndex)
    root.saveHistory()
    root.disarmPointer()
    root.rebuildDisplay()
    // Keep keyboard selection on the item that moved to/from the pinned group.
    for (var i = 0; i < displayModel.count; i++) {
      if (displayModel.get(i).historyIndex === historyIndex) {
        root.selectedIndex = i
        break
      }
    }
  }

  function rebuildDisplay() {
    var rows = ClipboardHistory.displayRows(root.history, root.filterText, 50)

    displayModel.clear()
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      displayModel.append({
        entryType: row.entryType,
        pinned: row.pinned,
        fullText: row.fullText,
        previewText: row.previewText,
        previewImage: row.previewImage ? Util.fileUrl(row.previewImage) : "",
        path: row.path,
        mime: row.mime,
        historyIndex: row.index
      })
    }

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function select(delta) {
    if (displayModel.count === 0) return
    root.disarmPointer()
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    }
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function selectAbsolute(index) {
    if (displayModel.count === 0) return
    root.disarmPointer()
    root.cursorActive = true
    root.selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1))
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
  }

  function disarmPointer() {
    pointerGate.reset()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    root.cursorActive = true
    root.selectedIndex = index
  }

  function activateIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.applySelected(row)
  }

  function copyIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.copySelected(row)
  }

  function openIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.openSelected(row)
  }

  function transferSelected(row, copyOnly) {
    if (!row || pasteProc.running) return
    // Resolve the complete entry now, before clipboard capture or a file reload
    // can reorder history. Never send a mutable history index to the helper.
    var entry = root.history[row.historyIndex]
    if (!entry) return
    if (entry.type === "image") {
      root.opened = false
      var args = [root.strataPath + "/bin/strata-clipboard-paste-file"]
      if (copyOnly) args.push("--copy-only")
      args.push(entry.mime || "image/png", entry.path)
      Quickshell.execDetached(args)
    } else if (entry.type === "text" && entry.text) {
      pasteProc.payload = entry.text
      pasteProc.command = [root.strataPath + "/bin/strata-clipboard-paste-text",
        copyOnly ? "--copy-only" : "--paste", "--stdin"]
      root.opened = false
      pasteProc.stdinEnabled = true
      pasteProc.running = true
      pasteProc.write(pasteProc.payload)
      pasteProc.stdinEnabled = false
      pasteProc.payload = ""
    }
  }

  function applySelected(row) {
    root.transferSelected(row, false)
  }

  function copySelected(row) {
    root.transferSelected(row, true)
  }

  function openSelected(row) {
    if (!row) return
    root.opened = false
    Quickshell.execDetached([root.strataPath + "/bin/strata-clipboard-open", "--history-index", String(row.historyIndex)])
  }

  Component.onCompleted: initProc.running = true

  ListModel { id: displayModel }

  Process {
    id: pasteProc
    property string payload: ""
  }

  Process {
    id: positionProc
    command: ["hyprctl", "-j", "--batch", "cursorpos; monitors"]
    stdout: StdioCollector {
      onStreamFinished: root.showAtCursor(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.showAtCursor("")
    }
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("[]")
    onFileChanged: reload()
  }

  // Reap watchers left behind by a previous shell instance, then start our
  // own. The pdeathsig on the watchers makes the kernel kill them whenever
  // the shell exits, however it exits, so no further lifecycle management.
  Process {
    id: initProc
    command: ["pkill", "-f", "wl-paste .*--watch .*/shell/plugins/clipboard/capture\\.sh"]
    onExited: {
      currentProc.running = true
      textWatchProc.running = true
      imageWatchProc.running = true
    }
  }

  Process {
    id: currentProc
    command: [root.captureScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.addClipboardJson(text)
    }
  }

  Process {
    id: textWatchProc
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "text", "--watch", root.captureScript, "text"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser {
      onRead: function(data) { root.addClipboardJson(data) }
    }
  }

  Process {
    id: imageWatchProc
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "image/png", "--watch", root.captureScript, "image/png"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser {
      onRead: function(data) { root.addClipboardJson(data) }
    }
  }

  // A watcher that dies takes clipboard history with it, silently: copying still
  // works, the picker still opens, and the old entries are all still there, so
  // nothing recorded until the next shell reload. Bring it back instead.
  Timer {
    id: watchRestartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (!textWatchProc.running) textWatchProc.running = true
      if (!imageWatchProc.running) imageWatchProc.running = true
    }
  }

  OverlayWindow {
    id: panel
    // Keep the input surface ready; only the cursor-anchored card is painted.
    parkWhenHidden: false
    shown: root.opened
    WlrLayershell.namespace: "strata-clipboard"

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      x: root.popupPosition
        ? ClipboardPlacement.axisPosition(root.popupPosition.x, width, panel.width, Style.gapsOut, Style.space(12))
        : (panel.width - width) / 2
      y: root.popupPosition
        ? ClipboardPlacement.axisPosition(root.popupPosition.y, height, panel.height, Style.gapsOut, Style.space(12))
        : (panel.height - height) / 2
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: root.clearConfirmOpen ? 20 : 0
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.clearConfirmOpen) {
            if (clearConfirm.handleKey(event)) event.accepted = true
            return
          }

          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.close()
            event.accepted = true
          } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            root.togglePinIndex(root.selectedIndex)
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Delete) {
            if (event.modifiers & Qt.ShiftModifier) root.requestClearHistory()
            else root.removeDisplayIndex(root.selectedIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Home) {
            root.selectAbsolute(0)
            event.accepted = true
          } else if (event.key === Qt.Key_End) {
            root.selectAbsolute(displayModel.count - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive && (event.modifiers & Qt.AltModifier)) root.openIndex(root.selectedIndex)
            else if (root.cursorActive && (event.modifiers & Qt.ShiftModifier)) root.copyIndex(root.selectedIndex)
            else if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else if (displayModel.count > 0) root.cursorActive = true
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: clearConfirm

          anchors.fill: parent
          opened: root.clearConfirmOpen
          z: 10
          message: "Delete unpinned clipboard history? Pinned items will be kept."
          confirmText: "Delete"
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelClearHistory()
          onConfirmed: root.confirmClearHistory()
        }
      }

      Column {
        id: content
        anchors.fill: parent
        anchors.topMargin: Math.max(root.contentMargin, card.borderTop)
        anchors.rightMargin: Math.max(root.contentMargin, card.borderRight)
        anchors.bottomMargin: Math.max(root.contentMargin, card.borderBottom)
        anchors.leftMargin: Math.max(root.contentMargin, card.borderLeft)
        spacing: root.contentSpacing

        Item {
          x: root.listPaintInset
          width: Math.max(0, parent.width - root.listPaintInset * 2)
          height: root.headerHeight

          Text {
            anchors.left: parent.left
            anchors.right: clearButton.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Clipboard history"
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            elide: Text.ElideRight
          }

          Button {
            id: clearButton
            anchors.right: closeButton.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            foreground: root.foreground
            enabled: root.history.length > 0
            opacity: enabled ? 1 : 0.4
            onClicked: root.requestClearHistory()
          }

          Button {
            id: closeButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "×"
            tooltipText: "Close (Esc)"
            foreground: root.foreground
            onClicked: root.close()
          }
        }

        Rectangle {
          x: root.listPaintInset
          width: Math.max(0, parent.width - root.listPaintInset * 2)
          height: root.headerHeight
          radius: root.cornerRadius
          color: Util.alpha(root.foreground, 0.06)
          border.width: Style.normalBorderWidth
          border.color: Util.alpha(root.border, 0.3)

          Text {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            text: root.filterText || "Search clipboard…"
            textFormat: Text.PlainText
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }
          MouseArea {
            anchors.fill: parent
            onClicked: keyCatcher.forceActiveFocus()
          }
        }

        Item {
          width: parent.width
          height: Math.max(0, content.height - root.headerHeight * 2 - footer.height - content.spacing * 3)

          ListView {
            id: resultList
            anchors.fill: parent
            // Delegates paint inside this clip, including their border pixels.
            pixelAligned: true
            model: displayModel
            clip: true
            spacing: Style.space(8)
            boundsBehavior: Flickable.StopAtBounds
            topMargin: root.listPaintInset
            bottomMargin: root.listPaintInset
            ScrollBar.vertical: PanelScrollBar {
              policy: ScrollBar.AsNeeded
              width: Style.space(6)
              parent: resultList.parent
              anchors.top: resultList.top
              anchors.bottom: resultList.bottom
              anchors.right: parent.right
              anchors.rightMargin: -root.contentMargin + Style.space(2)
            }

            delegate: Item {
              id: row
              required property int index
              required property bool pinned
              required property string entryType
              required property string previewText
              required property string fullText
              required property string previewImage
              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex

              width: ListView.view.width
              height: previewImage ? Style.space(104) : Style.space(78)

              Rectangle {
                id: rowSurface
                x: root.listPaintInset
                width: Math.max(0, row.width - root.listPaintInset * 2)
                height: row.height
                radius: root.cornerRadius
                color: row.hasCursor ? root.selectedBackground : Util.alpha(root.foreground, 0.045)
                border.width: Style.normalBorderWidth
                border.color: row.hasCursor ? root.border : Util.alpha(root.border, 0.22)

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: function(mouse) { root.selectFromPointer(row.index, rowSurface, mouse) }
                  onClicked: {
                    root.cursorActive = true
                    root.selectedIndex = row.index
                    root.activateIndex(row.index)
                  }
                }

                Text {
                  id: entryLabel
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(12)
                  anchors.top: parent.top
                  anchors.topMargin: Style.space(8)
                  anchors.right: pinButton.left
                  anchors.rightMargin: Style.space(4)
                  height: copyButton.height
                  text: row.entryType === "image" ? "Image" : row.entryType === "file" ? "Files" : "Text"
                  color: row.hasCursor ? root.selectedText : root.foreground
                  opacity: 0.65
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                }

                Button {
                  id: pinButton
                  anchors.right: copyButton.left
                  anchors.top: copyButton.top
                  iconText: row.pinned ? "󰐃" : "󰐂"
                  iconSize: Style.font.body
                  verticalPadding: Style.space(4)
                  horizontalPadding: Style.space(6)
                  active: row.pinned
                  foreground: row.hasCursor ? root.selectedText : root.foreground
                  tooltipText: row.pinned ? "Unpin (Ctrl+P)" : "Pin (Ctrl+P)"
                  onClicked: root.togglePinIndex(row.index)
                }

                Button {
                  id: copyButton
                  anchors.right: deleteButton.left
                  anchors.top: parent.top
                  anchors.topMargin: Style.space(4)
                  iconText: "󰆏"
                  iconSize: Style.font.body
                  verticalPadding: Style.space(4)
                  horizontalPadding: Style.space(6)
                  foreground: row.hasCursor ? root.selectedText : root.foreground
                  tooltipText: "Copy without pasting (Shift+Enter)"
                  onClicked: root.copyIndex(row.index)
                }

                Button {
                  id: deleteButton
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(4)
                  anchors.top: copyButton.top
                  iconText: "×"
                  iconSize: Style.font.body
                  verticalPadding: Style.space(4)
                  horizontalPadding: Style.space(6)
                  foreground: row.hasCursor ? root.selectedText : root.foreground
                  tooltipText: "Delete item (Delete)"
                  onClicked: root.removeDisplayIndex(row.index)
                }

                Text {
                  visible: !row.previewImage
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: copyButton.bottom
                  anchors.bottom: parent.bottom
                  anchors.margins: Style.space(12)
                  anchors.topMargin: Style.space(4)
                  text: row.fullText
                  textFormat: Text.PlainText
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WrapAnywhere
                  elide: Text.ElideRight
                  maximumLineCount: 2
                }

                Image {
                  visible: row.previewImage.length > 0
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: copyButton.bottom
                  anchors.bottom: parent.bottom
                  anchors.margins: Style.space(12)
                  anchors.topMargin: Style.space(4)
                  source: row.previewImage
                  sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                  sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                  fillMode: Image.PreserveAspectFit
                  horizontalAlignment: Image.AlignLeft
                  asynchronous: true
                  smooth: true
                }
              }
            }
          }

          Text {
            anchors.fill: parent
            anchors.margins: Style.space(12)
            visible: displayModel.count === 0
            text: root.history.length === 0 ? "Your clipboard is empty.\nCopied text and images will appear here." : "No matching items"
            textFormat: Text.PlainText
            color: root.foreground
            opacity: 0.65
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
          }
        }

        Text {
          id: footer
          width: parent.width
          height: Style.font.caption * 2
          text: "Enter paste · Ctrl+P pin"
          color: root.foreground
          opacity: 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }
      }
    }
  }
}
