import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.services

// When an app needs your password to change something on the system. ETEA answers for
// polkit itself, so pkexec, mounting a disk or installing a package ask here, in the same
// sky as everything else. Escape says no.
Scope {
    id: root

    readonly property var flow: agent.flow

    PolkitAgent {
        id: agent
    }

    PanelWindow {
        id: panel

        property real shown: agent.isActive ? 1 : 0
        readonly property bool waiting: root.flow !== null && !root.flow.isResponseRequired && !root.flow.isCompleted

        function answer() {
            if (!root.flow?.isResponseRequired)
                return;
            root.flow.submit(field.text);
            field.text = "";
        }

        function refuse() {
            root.flow?.cancelAuthenticationRequest();
        }

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: shown > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:polkit"
        WlrLayershell.keyboardFocus: agent.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Behavior on shown {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        Connections {
            target: agent

            function onIsActiveChanged() {
                field.text = "";
                if (agent.isActive)
                    field.forceActiveFocus();
            }
        }

        // A wrong password shakes the card, the way the lock does
        Connections {
            target: root.flow

            function onFailedChanged() {
                if (root.flow.failed)
                    shake.restart();
            }

            function onIsResponseRequiredChanged() {
                if (root.flow.isResponseRequired)
                    field.forceActiveFocus();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.launcherShade
            opacity: panel.shown * 0.8

            MouseArea {
                anchors.fill: parent
            }
        }

        Item {
            id: card

            anchors.centerIn: parent
            width: 460
            height: content.implicitHeight + 56
            opacity: panel.shown

            transform: Translate {
                id: nudge

                y: (1 - panel.shown) * 20
            }

            SequentialAnimation {
                id: shake

                loops: 2
                NumberAnimation { target: nudge; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: nudge; property: "x"; to: 10; duration: 70 }
                NumberAnimation { target: nudge; property: "x"; to: 0; duration: 50 }
            }

            HandCard {
                anchors.fill: parent
                seed: "polkit"
                tint: root.flow?.failed ? "#f0705f" : "#ffc98a"
                rise: 0.08
                alive: panel.visible
            }

            ColumnLayout {
                id: content

                x: 28
                y: 28
                width: parent.width - 56
                spacing: 12

                RowLayout {
                    spacing: 12

                    Icon {
                        name: "lock"
                        size: 24
                    }

                    Text {
                        text: Lang.t("Une autorisation est demandée")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 19
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    wrapMode: Text.WordWrap
                    color: Qt.alpha(Theme.text, 0.8)
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    implicitHeight: 42
                    radius: 0
                    color: Qt.alpha(Theme.windowLit, field.activeFocus ? 0.14 : 0.08)

                    TextInput {
                        id: field

                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: root.flow?.isResponseRequired ?? false
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "✦"
                        color: Theme.text
                        selectionColor: Qt.alpha(Theme.windowLit, 0.4)
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.letterSpacing: echoMode === TextInput.Password ? 3 : 0
                        clip: true
                        onAccepted: panel.answer()
                        Keys.onEscapePressed: panel.refuse()
                    }

                    Text {
                        visible: field.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        x: 14
                        text: panel.waiting ? Lang.t("On vérifie…") : (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || Lang.t("Mot de passe")
                        color: Qt.alpha(Theme.text, 0.4)
                        font.family: Theme.font
                        font.pixelSize: 14
                    }
                }

                Text {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: root.flow?.failed ? Lang.t("Ce n'est pas le bon mot de passe.") : root.flow?.supplementaryMessage ?? ""
                    wrapMode: Text.WordWrap
                    color: root.flow?.failed || root.flow?.supplementaryIsError ? "#f0947c" : Qt.alpha(Theme.text, 0.6)
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: 4
                    spacing: 10

                    Choice {
                        label: Lang.t("Annuler")
                        onPicked: panel.refuse()
                    }

                    Choice {
                        label: Lang.t("Autoriser")
                        strong: true
                        onPicked: panel.answer()
                    }
                }
            }
        }
    }

    component Choice: Rectangle {
        id: button

        property string label: ""
        property bool strong: false

        signal picked()

        implicitWidth: caption.implicitWidth + 32
        implicitHeight: 36
        radius: 0
        color: Qt.alpha(Theme.windowLit, strong ? (hover.containsMouse ? 0.34 : 0.24) : (hover.containsMouse ? 0.14 : 0.06))

        Text {
            id: caption

            anchors.centerIn: parent
            text: button.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
        }

        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.picked()
        }
    }
}
