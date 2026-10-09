import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root

    width: 1920
    height: 1080
    // Keep the greeter visually continuous with Strata's Quickshell lock
    // screen. SDDM cannot reuse Quickshell components, so this is deliberately
    // a small, dependency-free equivalent using the same Catppuccin palette.
    color: "#11111b"

    readonly property color foreground: "#cdd6f4"
    readonly property color muted: "#bac2de"
    readonly property color surface: "#1e1e2e"
    readonly property color fieldSurface: "#181825"
    readonly property color border: "#89b4fa"
    readonly property color inactiveBorder: "#45475a"
    readonly property color error: "#f38ba8"
    readonly property string fontFamily: config.stringValue("font") || "JetBrainsMono Nerd Font"
    property string loginError: ""

    function login() {
        if (username.text.trim().length === 0 || password.text.length === 0) {
            loginError = "Enter your username and password"
            return
        }

        loginError = ""
        sddm.login(username.text.trim(), password.text, sessionPicker.index)
        password.text = ""
    }

    Rectangle {
        anchors.fill: parent
        color: "#11000000"
    }

    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -170
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Math.max(48, Math.round(Math.min(root.width, root.height) * 0.067))
        font.weight: Font.DemiBold
        text: Qt.formatDateTime(new Date(), "dddd  HH:mm")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "dddd  HH:mm")
    }

    Text {
        anchors.top: clock.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: 18
    }

    Rectangle {
        id: loginCard
        width: Math.min(420, parent.width - 48)
        height: content.implicitHeight + 32
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 100
        color: "transparent"
        radius: 12

        Column {
            id: content
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 12

            Text {
                width: parent.width
                text: "STRATA"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 16
                font.letterSpacing: 3
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: "Sign in to unlock your session"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
            }

            TextField {
                id: username
                width: parent.width
                height: 48
                placeholderText: "Username"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 15
                selectByMouse: true
                background: Rectangle {
                    color: root.fieldSurface
                    radius: 8
                    border.width: username.activeFocus ? 2 : 1
                    border.color: username.activeFocus ? root.border : root.inactiveBorder
                }
                Keys.onReturnPressed: password.forceActiveFocus()
            }

            TextField {
                id: password
                width: parent.width
                height: 48
                placeholderText: "Password"
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 15
                selectByMouse: true
                background: Rectangle {
                    color: root.fieldSurface
                    radius: 8
                    border.width: password.activeFocus ? 2 : 1
                    border.color: password.activeFocus ? root.border : root.inactiveBorder
                }
                Keys.onReturnPressed: root.login()
            }

            ComboBox {
                id: sessionPicker
                width: parent.width
                model: sessionModel
                textRole: "name"
                index: sessionModel.lastIndex
                font.family: root.fontFamily
                font.pixelSize: 13
                background: Rectangle {
                    color: root.fieldSurface
                    radius: 8
                    border.width: sessionPicker.activeFocus ? 2 : 1
                    border.color: sessionPicker.activeFocus ? root.border : root.inactiveBorder
                }
            }

            Button {
                width: parent.width
                height: 44
                text: "Sign in"
                font.family: root.fontFamily
                font.pixelSize: 14
                onClicked: root.login()
                background: Rectangle {
                    radius: 8
                    color: parent.down ? "#74c7ec" : (parent.hovered ? "#b4befe" : root.border)
                }
                contentItem: Text {
                    text: parent.text
                    color: "#11111b"
                    font: parent.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                width: parent.width
                visible: root.loginError.length > 0
                text: root.loginError
                color: root.error
                font.family: root.fontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: loginCard.bottom
        anchors.topMargin: 24
        text: "Strata · Hyprland"
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: 12
    }

    Component.onCompleted: username.forceActiveFocus()
}
