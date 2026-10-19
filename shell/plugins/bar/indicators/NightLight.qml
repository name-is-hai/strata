import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  readonly property var nightlightService: bar?.shell?.firstPartyServiceFor("strata.nightlight")
  readonly property bool lightOn: nightlightService ? nightlightService.enabled : false
  readonly property color panelText: Color.popups.text
  readonly property color panelMuted: Qt.darker(panelText, 1.45)
  property bool editingLocation: false

  active: lightOn
  alwaysVisible: true
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: nightlightService ? nightlightService.temperature + "K · " + nightlightService.statusText : "Night Light"
  inactiveTooltipText: "Night Light"

  function toggleNightlight() {
    if (nightlightService) nightlightService.toggle()
  }

  onPressed: function(button) {
    if (button === Qt.RightButton) root.toggleNightlight()
    else popup.open = !popup.open
  }

  PopupCard {
    id: popup
    anchorItem: root
    owner: root
    bar: root.bar
    triggerMode: "click"
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    ColumnLayout {
      id: content
      anchors.fill: parent
      spacing: Style.space(10)

      RowLayout {
        Layout.fillWidth: true
        Text {
          Layout.fillWidth: true
          text: "Night light"
          color: root.panelText
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Button {
          text: root.lightOn ? "On" : "Off"
          active: root.lightOn
          foreground: root.panelText
          fontFamily: Style.font.family
          onClicked: root.toggleNightlight()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Text {
          Layout.fillWidth: true
          text: root.nightlightService ? root.nightlightService.statusText : "Loading…"
          color: root.panelMuted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Text {
          text: root.nightlightService ? root.nightlightService.temperature + " K" : ""
          color: root.panelText
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      PanelSlider {
        Layout.fillWidth: true
        bar: root.bar
        minimum: 1000
        maximum: 6500
        step: 100
        integer: true
        value: root.nightlightService ? root.nightlightService.temperature : 6500
        onMoved: function(value) { if (root.nightlightService) root.nightlightService.setTemperature(value) }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)
        Repeater {
          model: [
            { key: "day", label: "Day" },
            { key: "evening", label: "Evening" },
            { key: "night", label: "Night" },
            { key: "candle", label: "Candle" }
          ]
          Button {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.label
            foreground: root.panelText
            fontFamily: Style.font.family
            onClicked: if (root.nightlightService) root.nightlightService.preset(modelData.key)
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: root.panelMuted; opacity: 0.35 }

      RowLayout {
        Layout.fillWidth: true
        Text {
          Layout.fillWidth: true
          text: "Schedule"
          color: root.panelText
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
        Button {
          text: root.nightlightService && root.nightlightService.mode === "auto" ? "Automatic" : "Manual"
          active: root.nightlightService && root.nightlightService.mode === "auto"
          foreground: root.panelText
          fontFamily: Style.font.family
          onClicked: if (root.nightlightService) root.nightlightService.setMode(root.nightlightService.mode === "auto" ? "manual" : "auto")
        }
      }

      Text {
        Layout.fillWidth: true
        text: root.nightlightService
          ? (root.nightlightService.hasLocation
              ? "Sunrise " + root.nightlightService.sunriseText + " · Sunset " + root.nightlightService.sunsetText
              : "Using 06:00 / 18:00 until a location is set")
          : ""
        color: root.panelMuted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      ColumnLayout {
        Layout.fillWidth: true
        visible: root.nightlightService && root.nightlightService.mode === "auto"
        spacing: Style.space(2)

        RowLayout {
          Layout.fillWidth: true
          Text { Layout.fillWidth: true; text: "Day temperature"; color: root.panelMuted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: root.nightlightService ? root.nightlightService.dayTemperature + " K" : ""; color: root.panelText; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
        PanelSlider {
          Layout.fillWidth: true
          bar: root.bar
          minimum: 4000
          maximum: 6500
          step: 100
          integer: true
          value: root.nightlightService ? root.nightlightService.dayTemperature : 6500
          onMoved: function(value) { if (root.nightlightService) root.nightlightService.setDayTemperature(value) }
        }

        RowLayout {
          Layout.fillWidth: true
          Text { Layout.fillWidth: true; text: "Night temperature"; color: root.panelMuted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: root.nightlightService ? root.nightlightService.nightTemperature + " K" : ""; color: root.panelText; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
        PanelSlider {
          Layout.fillWidth: true
          bar: root.bar
          minimum: 1000
          maximum: 4500
          step: 100
          integer: true
          value: root.nightlightService ? root.nightlightService.nightTemperature : 3400
          onMoved: function(value) { if (root.nightlightService) root.nightlightService.setNightTemperature(value) }
        }

        RowLayout {
          Layout.fillWidth: true
          Text { Layout.fillWidth: true; text: "Transition"; color: root.panelMuted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: root.nightlightService ? root.nightlightService.transitionMinutes + " min" : ""; color: root.panelText; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
        PanelSlider {
          Layout.fillWidth: true
          bar: root.bar
          minimum: 0
          maximum: 120
          step: 5
          integer: true
          value: root.nightlightService ? root.nightlightService.transitionMinutes : 30
          onMoved: function(value) { if (root.nightlightService) root.nightlightService.setTransition(value) }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Text {
          Layout.fillWidth: true
          text: root.nightlightService && root.nightlightService.hasLocation
            ? "Location set · " + Number(root.nightlightService.latitude).toFixed(2) + ", " + Number(root.nightlightService.longitude).toFixed(2)
            : "Location not set"
          color: root.panelMuted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Button {
          text: root.editingLocation ? "Close" : (root.nightlightService && root.nightlightService.hasLocation ? "Change" : "Set location")
          foreground: root.panelText
          fontFamily: Style.font.family
          onClicked: root.editingLocation = !root.editingLocation
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: root.editingLocation
        TextField {
          id: latitudeField
          Layout.fillWidth: true
          placeholderText: "Latitude"
          text: root.nightlightService && root.nightlightService.hasLocation ? String(root.nightlightService.latitude) : ""
          color: root.panelText
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          selectByMouse: true
          background: BorderSurface { color: Color.popups.background; borderSpec: Border.flat(root.panelMuted, 1); radius: 0 }
        }
        TextField {
          id: longitudeField
          Layout.fillWidth: true
          placeholderText: "Longitude"
          text: root.nightlightService && root.nightlightService.hasLocation ? String(root.nightlightService.longitude) : ""
          color: root.panelText
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          selectByMouse: true
          background: BorderSurface { color: Color.popups.background; borderSpec: Border.flat(root.panelMuted, 1); radius: 0 }
        }
        Button {
          text: "Save"
          foreground: root.panelText
          fontFamily: Style.font.family
          onClicked: {
            if (root.nightlightService && root.nightlightService.setLocation(latitudeField.text, longitudeField.text))
              root.editingLocation = false
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: root.nightlightService && root.nightlightService.lastError !== ""
        text: root.nightlightService ? root.nightlightService.lastError : ""
        color: Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        Button {
          Layout.fillWidth: true
          text: root.nightlightService && root.nightlightService.pauseUntil ? "Resume schedule" : "Pause 1 hour"
          foreground: root.panelText
          fontFamily: Style.font.family
          onClicked: {
            if (!root.nightlightService) return
            if (root.nightlightService.pauseUntil) root.nightlightService.clearPause()
            else root.nightlightService.pauseFor(3600)
          }
        }
        Button {
          Layout.fillWidth: true
          text: "Until sunrise"
          foreground: root.panelText
          fontFamily: Style.font.family
          onClicked: if (root.nightlightService) root.nightlightService.pauseUntilSunrise()
        }
      }
    }
  }
}
