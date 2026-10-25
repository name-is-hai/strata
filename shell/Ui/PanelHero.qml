import QtQuick
import Quickshell
import qs.Commons

PanelHeaderSurface {
  id: root

  property Component iconComponent: null
  property string title: ""
  property string meta: ""
  property string detail: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property real iconSize: Style.font.display
  property real iconOpacity: 1.0
  property alias metaOpacity: metaText.opacity
  headerForeground: foreground

  // Older plugins place their hero in a scrolling Column. Leave the source
  // object in place for bindings, but let KeyboardPanel render it in its
  // fixed header slot. Explicit panelHeader assignments take precedence.
  property bool autoDock: true
  property var _headerHost: null
  readonly property var _headerWindow: root.QsWindow.window
  // The hero itself is hidden while docked. Its page's visibility decides
  // whether it may supply the fixed header, so hidden plugin pages cannot
  // reserve header space or leak their controls onto another page.
  readonly property bool _headerPageVisible: parent ? parent.visible : false
  readonly property bool headerDocked: _headerHost !== null
    && _headerHost.autoDockHeaders && !_headerHost.panelHeader
    && _headerHost.automaticHeaderSource === root
  readonly property real naturalHeight: Math.max(Style.space(58), heroLabels.implicitHeight + Style.space(20), trailingLoader.implicitHeight + Style.space(20))

  function syncHeaderHost() {
    var window = root._headerWindow
    var eligible = autoDock && root._headerPageVisible && window
      && window.autoDockHeaders && !window.panelHeader
      && typeof window.registerAutomaticHeader === "function"
    if (eligible && _headerHost === window && window.automaticHeaderSource === root) return
    if (_headerHost && typeof _headerHost.releaseAutomaticHeader === "function")
      _headerHost.releaseAutomaticHeader(root)
    _headerHost = null
    if (eligible && window.registerAutomaticHeader(root)) _headerHost = window
  }
  on_HeaderWindowChanged: Qt.callLater(syncHeaderHost)
  on_HeaderPageVisibleChanged: Qt.callLater(syncHeaderHost)
  onAutoDockChanged: Qt.callLater(syncHeaderHost)
  Connections {
    target: root._headerWindow
    ignoreUnknownSignals: true
    function onAutomaticHeaderSourceChanged() { Qt.callLater(root.syncHeaderHost) }
    function onAutoDockHeadersChanged() { Qt.callLater(root.syncHeaderHost) }
    function onPanelHeaderChanged() { Qt.callLater(root.syncHeaderHost) }
  }
  Component.onCompleted: Qt.callLater(syncHeaderHost)
  Component.onDestruction: {
    if (_headerHost && typeof _headerHost.releaseAutomaticHeader === "function")
      _headerHost.releaseAutomaticHeader(root)
  }
  visible: !headerDocked

  // Optional control pinned to the trailing edge of the hero — a ToggleSwitch,
  // a small button. The hero centers it against the labels and reserves the
  // space itself, so callers never do the geometry.
  property Component trailingControl: null

  readonly property color dim: Util.alpha(foreground, 0.6)
  readonly property real trailingInset: trailingLoader.item && trailingLoader.item.visible ? trailingLoader.width + Style.space(12) : 0

  width: parent ? parent.width : implicitWidth
  implicitHeight: headerDocked ? 0 : naturalHeight

  Column {
    id: heroLabels
    anchors.left: parent.left
    anchors.leftMargin: Style.space(16)
    anchors.right: parent.right
    anchors.rightMargin: root.trailingInset + Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Row {
      id: titleRow
      visible: root.title !== "" || detailPill.visible
      width: parent.width

      Text {
        textFormat: Text.PlainText
        visible: root.title !== ""
        text: root.title
        width: Math.min(implicitWidth, Math.max(0, parent.width - (detailPill.visible ? detailPill.implicitWidth + Style.space(8) : 0)))
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }

      Item {
        width: Math.max(0, parent.width - parent.children[0].width - detailPill.implicitWidth)
        height: 1
      }

      Item {
        id: detailPill
        visible: root.detail !== ""
        implicitWidth: Math.min(detailText.implicitWidth, parent.width * 0.45)
        implicitHeight: detailText.implicitHeight
        anchors.verticalCenter: parent.verticalCenter

        Text {
          id: detailText
          textFormat: Text.PlainText
          anchors.centerIn: parent
          width: parent.width
          text: root.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    Text {
      id: metaText
      textFormat: Text.PlainText
      width: parent.width
      text: root.meta
      visible: text !== ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Loader {
    id: trailingLoader
    active: !root.headerDocked
    sourceComponent: root.trailingControl
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
  }
}
