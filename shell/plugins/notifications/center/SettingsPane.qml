pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import "Preferences.js" as Preferences
import "Translations.js" as Translations
import "components"

Item {
  id: root
  required property var settings
  required property var popupSettings
  required property string language
  property bool popupAvailable: false
  property bool popupInstalled: false
  property bool loading: false
  property bool saving: false
  property string error: ""
  readonly property color secondary: Qt.tint(Color.popups.background, Qt.alpha(Color.popups.text, 0.7))
  readonly property int padding: Style.space(20)
  property int currentTab: 0
  readonly property var tabs: ["Center", "Popups", "Quiet & privacy"]
  readonly property var groups: Preferences.settingsGroups.filter(function(group) { return group.tab === currentTab })
  implicitHeight: settingsHeader.height + navigation.height + settingsBody.implicitHeight
  onCurrentTabChanged: Qt.callLater(resetScroll)
  signal save(string scope, string key, var value)
  signal back()
  signal clearError()
  signal pasteFailed(string message)
  function tr(label) { return Translations.text(label, language) }
  function focusBack() { backButton.forceActiveFocus() }
  function resetScroll() { settingsScroll.contentY = 0 }
  Keys.onEscapePressed: root.back()

  // Keep native Tab focus visible when the complete settings page needs to scroll.
  function keepFocusVisible(item) {
    if (!visible || !item) return
    var ancestor = item
    while (ancestor && ancestor !== settingsScroll.contentItem) ancestor = ancestor.parent
    if (!ancestor) return
    var point = item.mapToItem(settingsScroll.contentItem, 0, 0)
    if (point.y < settingsScroll.contentY) settingsScroll.contentY = Math.max(0, point.y - Style.space(8))
    else if (point.y + item.height > settingsScroll.contentY + settingsScroll.height)
      settingsScroll.contentY = Math.max(0, Math.min(settingsScroll.contentHeight - settingsScroll.height, point.y + item.height - settingsScroll.height + Style.space(8)))
  }
  Connections {
    target: root.Window.window
    function onActiveFocusItemChanged() { root.keepFocusVisible(target.activeFocusItem) }
  }
  PanelHeaderSurface {
    id: settingsHeader
    width: parent.width
    height: Style.space(72)
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: root.padding
      anchors.rightMargin: root.padding
      spacing: Style.space(12)
      NotificationAction {
        id: backButton
        objectName: "settingsBack"
        iconName: "back"
        foreground: Color.popups.text
        tooltipText: root.tr("Back")
        onClicked: root.back()
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)
        Text {
          Layout.fillWidth: true
          text: root.tr("Notification settings")
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          text: root.tr(root.saving ? "Saving…" : "Changes save automatically")
          color: root.secondary
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
  Item {
    id: navigation
    anchors.top: settingsHeader.bottom
    width: parent.width
    height: Style.space(58)
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: root.padding
      anchors.rightMargin: root.padding
      anchors.topMargin: Style.space(10)
      anchors.bottomMargin: Style.space(10)
      spacing: Style.space(4)
      Repeater {
        model: root.tabs
        Button {
          required property string modelData
          required property int index
          objectName: "notificationSettingsTab" + index
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          text: root.tr(modelData)
          fontSize: Style.font.caption
          horizontalPadding: Style.space(5)
          foreground: Color.popups.text
          selected: root.currentTab === index
          focusable: true
          onClicked: root.currentTab = index
        }
      }
    }
  }
  Flickable {
    id: settingsScroll
    objectName: "settingsScroll"
    anchors.top: navigation.bottom
    anchors.bottom: parent.bottom
    width: parent.width
    contentWidth: width
    contentHeight: settingsBody.implicitHeight
    clip: true
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds
    onContentHeightChanged: contentY = Math.max(0, Math.min(contentY, contentHeight - height))
    onHeightChanged: contentY = Math.max(0, Math.min(contentY, contentHeight - height))
    Controls.ScrollBar.vertical: PanelScrollBar { policy: Controls.ScrollBar.AsNeeded }
    Column {
      id: settingsBody
      width: parent.width
      leftPadding: root.padding
      rightPadding: root.padding
      bottomPadding: root.padding
      spacing: Style.space(14)
      Text {
        width: root.width - root.padding * 2
        visible: root.error !== ""
        text: root.error
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.space(12)
        Accessible.role: Accessible.AlertMessage
      }
      Repeater {
        model: root.groups
        BorderSurface {
          id: section
          required property var modelData
          width: root.width - root.padding * 2
          implicitHeight: sectionBody.implicitHeight + Style.space(28)
          color: Qt.alpha(Color.popups.text, 0.025)
          borderSpec: Border.flat(Qt.alpha(Color.popups.text, 0.12), 1)
          radius: Style.cornerRadius
          Column {
            id: sectionBody
            x: Style.space(14)
            y: Style.space(14)
            width: parent.width - Style.space(28)
            spacing: Style.space(14)
            Column {
              width: parent.width
              spacing: Style.space(4)
              Text {
                width: parent.width
                text: root.tr(section.modelData.title)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                wrapMode: Text.WordWrap
              }
              Text {
                width: parent.width
                text: root.tr(section.modelData.description)
                color: root.secondary
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }
            Rectangle { width: parent.width; height: 1; color: Qt.alpha(Color.popups.text, 0.08) }
            Text {
              objectName: section.modelData.title + "-availability"
              width: parent.width
              visible: section.modelData.scope === "popups" && !root.popupAvailable
              text: root.tr(root.loading ? "Reading settings…" : root.popupInstalled ? "Plugin not enabled" : "Plugin not installed")
              wrapMode: Text.WordWrap
              color: root.secondary
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Repeater {
              model: section.modelData.scope === "center" || root.popupAvailable ? section.modelData.keys : []
              SettingsField {
                required property string modelData
                width: sectionBody.width
                scope: section.modelData.scope
                field: Preferences.field(scope, modelData)
                settings: scope === "center" ? root.settings : root.popupSettings
                visible: field.key !== "displayName" || String(root.popupSettings.displayMode || "active") === "specific"
                language: root.language
                enabled: !root.saving && (scope === "center" || root.popupAvailable)
                opacity: enabled ? 1 : 0.55
                onSave: function(value) { root.save(scope, field.key, value) }
                onClearError: root.clearError()
                onPasteFailed: function(message) { root.pasteFailed(message) }
              }
            }
          }
        }
      }
    }
  }
}
