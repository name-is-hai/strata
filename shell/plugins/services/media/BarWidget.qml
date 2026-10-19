import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui
import qs.Commons

// Adapted from debba/omarchy-media-control (MIT); see MEDIA-CONTROL-LICENSE.
// Uses Strata's existing singleton so media keys and source selection agree.
Panel {
  id: root
  moduleName: "strata.media"
  ipcTarget: "strata.media"
  readonly property var mediaService: bar && bar.shell ? bar.shell.firstPartyServiceFor("strata.media") : null
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []
  readonly property bool hideWhenPaused: settings && settings.hideWhenPaused === true
  readonly property int panelWidth: Math.max(260, Math.min(600, Number(setting("panelWidth", 380)) || 380))

  readonly property bool hasMedia: activePlayer !== null && !!(activePlayer.trackTitle || activePlayer.trackArtist || activePlayer.lengthSupported && activePlayer.length > 0)
  readonly property bool isPlaying: activePlayer !== null && activePlayer.isPlaying
  readonly property bool shouldShow: hasMedia && (isPlaying || !hideWhenPaused || opened)

  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  // Resolve the player's .desktop entry so we can show the proper app name
  // and icon (e.g. Zen reports desktopEntry "zen" whose icon is "zen-browser").
  readonly property var appEntry: activePlayer && activePlayer.desktopEntry ? DesktopEntries.byId(activePlayer.desktopEntry) : null
  readonly property string appName: appEntry && appEntry.name ? appEntry.name
    : activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "Media") : "Media"
  readonly property string appIcon: {
    if (appEntry && appEntry.icon) {
      var themed = Quickshell.iconPath(appEntry.icon, true)
      if (themed) return themed
    }
    if (activePlayer && activePlayer.desktopEntry) return Quickshell.iconPath(activePlayer.desktopEntry, true) || ""
    return ""
  }

  readonly property bool hasLength: !!activePlayer && activePlayer.lengthSupported && activePlayer.length > 0
  readonly property bool hasPosition: !!activePlayer && activePlayer.positionSupported
  readonly property real trackLength: {
    var p = activePlayer
    return p && p.lengthSupported && p.length > 0 ? p.length : 0
  }
  readonly property real trackPosition: {
    var p = activePlayer
    if (!p || !p.positionSupported) return 0
    var pos = p.position
    var len = p.lengthSupported && p.length > 0 ? p.length : 0
    return len > 0 ? Math.min(pos, len) : pos
  }


  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) seconds = 0
    var total = Math.floor(seconds)
    var h = Math.floor(total / 3600)
    var m = Math.floor((total % 3600) / 60)
    var s = total % 60
    var mm = h > 0 && m < 10 ? "0" + m : "" + m
    var ss = s < 10 ? "0" + s : "" + s
    return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss
  }

  function act(action) {
    if (!mediaService || !activePlayer) return
    mediaService.runAction(action, false, mediaService.playerKey(activePlayer))
  }

  visible: shouldShow
  implicitWidth: shouldShow ? indicator.implicitWidth : 0
  implicitHeight: indicator.implicitHeight
  onHasMediaChanged: if (!hasMedia) close()
  onOpenedChanged: if (opened) viewport.contentY = 0

  BarIconButton {
    id: indicator
    anchors.fill: parent
    bar: root.bar
    text: root.isPlaying ? "󰐊" : "󰏤"
    active: root.opened
    tooltipText: root.appName + (root.title ? " · " + root.title : "")
    onPressed: function(button) {
      if (button === Qt.LeftButton) root.toggle()
      else if (button === Qt.RightButton) root.act("playPause")
      else if (button === Qt.MiddleButton) root.act("next")
    }
    onWheelMoved: function(delta) { if (delta !== 0) root.act(delta > 0 ? "previous" : "next") }
  }
  Timer {
    interval: 1000
    repeat: true
    running: root.opened && root.isPlaying && root.hasPosition
    triggeredOnStart: true
    onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
  }
  KeyboardPanel {
    id: popup
    anchorItem: indicator
    bar: root.bar
    owner: root
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(600))
    focusTarget: keys

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.act("playPause")
      onMoveRequested: function(dx, dy) {
        if (dx && root.activePlayer && root.activePlayer.canSeek && root.hasPosition)
          root.activePlayer.position = Math.max(0, Math.min(root.trackLength || Infinity, root.trackPosition + dx * 5))
        else if (dy && root.sourcePlayers.length > 1 && root.mediaService) {
          var key = root.mediaService.playerKey(root.activePlayer)
          var index = root.sourcePlayers.findIndex(function(player) { return root.mediaService.playerKey(player) === key })
          var next = root.sourcePlayers[(Math.max(0, index) + dy + root.sourcePlayers.length) % root.sourcePlayers.length]
          root.mediaService.selectPlayer(root.mediaService.playerKey(next))
        }
      }
      Flickable {
        id: viewport
        anchors.fill: parent
        anchors.rightMargin: Style.space(16)
        clip: true
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: PanelScrollBar {
          width: Style.space(6)
          parent: viewport.parent
          anchors.top: viewport.top
          anchors.bottom: viewport.bottom
          anchors.right: parent.right
        }
    Column {
      id: column
      width: parent.width
      spacing: Style.space(10)

      // ── App header ────────────────────────────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(8)

        Item {
          width: Style.space(18)
          height: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter

          Image {
            anchors.fill: parent
            source: root.appIcon
            visible: root.appIcon !== ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize: Qt.size(width * 2, height * 2)
          }

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: root.appIcon === ""
            text: "󰝚"
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.appName
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          width: parent.width - Style.space(34) - castButton.implicitWidth
        }

        Button {
          id: castButton
          iconText: "󰄙"
          tooltipText: "Cast a local media file to a TV"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: {
            root.close()
            Quickshell.execDetached(["strata-shell", "shell", "summon", "strata.cast"])
          }
        }
      }

      // ── Artwork + track + controls ────────────────────────────────
      Row {
        id: mainRow
        width: parent.width
        spacing: Style.space(12)

        BorderSurface {
          id: art
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
          anchors.verticalCenter: parent.verticalCenter

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            id: cover
            source: root.artUrl
            visible: root.artUrl !== "" && status === Image.Ready
          }

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          id: trackInfo
          width: mainRow.width - art.width - controls.width - mainRow.spacing * 2
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            textFormat: Text.PlainText
            text: root.title || (root.hasMedia ? "Untitled media" : "Nothing playing")
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.album
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }

        Row {
          id: controls
          spacing: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter

          ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒮"
            foreground: root.bar.foreground
            enabled: root.activePlayer && root.activePlayer.canGoPrevious
            onClicked: root.act("previous")
          }

          ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: root.isPlaying ? "󰏤" : "󰐊"
            iconSize: Style.font.iconLarge
            // Nerd Font play/pause glyphs sit low in their line box.
            iconOffsetY: -iconSize * 0.08
            foreground: root.bar.foreground
            enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
            onClicked: root.act("playPause")
          }

          ControlButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒭"
            foreground: root.bar.foreground
            enabled: root.activePlayer && root.activePlayer.canGoNext
            onClicked: root.act("next")
          }
        }
      }

      // ── Seek bar ──────────────────────────────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(10)
        visible: root.hasLength

        Text {
          textFormat: Text.PlainText
          id: elapsed
          anchors.verticalCenter: parent.verticalCenter
          text: root.formatTime(seek.dragging ? seek.liveValue : root.trackPosition)
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          width: Math.max(Style.space(40), implicitWidth)
        }

        PanelSlider {
          id: seek
          wheelEnabled: false
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - elapsed.width - total.width - parent.spacing * 2
          bar: root.bar
          minimum: 0
          maximum: Math.max(1, root.trackLength)
          step: 1
          value: root.trackPosition
          enabled: root.activePlayer && root.activePlayer.canSeek
          opacity: enabled ? 1.0 : 0.6
          onReleased: function(v) {
            if (root.activePlayer && root.activePlayer.canSeek) root.activePlayer.position = v
          }
        }

        Text {
          textFormat: Text.PlainText
          id: total
          anchors.verticalCenter: parent.verticalCenter
          text: root.formatTime(root.trackLength)
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          width: Math.max(Style.space(40), implicitWidth)
          horizontalAlignment: Text.AlignRight
        }
      }

      // ── Source picker (only with several players) ─────────────────
      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData
            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceApp: player ? (player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceTrack: player ? [player.trackTitle, player.trackArtist].filter(Boolean).join(" · ") : ""

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰐊" : "󰏤"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceApp
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceTrack
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
      }
    }
  }
}
