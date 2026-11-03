import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.services

// Lang.t("Et maintenant ?") The way out of a session. Anything that closes your work asks twice,
// so a stray click can't take it away.
Scope {
    id: root

    GlobalShortcut {
        appid: "etea"
        name: "session"
        onPressed: Menus.sessionOpen = !Menus.sessionOpen
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            Menus.sessionOpen = !Menus.sessionOpen;
        }
    }

    PanelWindow {
        id: panel

        readonly property var actions: [
            { icon: "lock", label: Lang.t("Verrouiller"), tint: Theme.windowLit, run: () => Menus.locked = true },
            { icon: "sleep", label: Lang.t("Veille"), tint: Theme.windowLit, command: ["systemctl", "suspend"] },
            { icon: "logout", label: Lang.t("Déconnecter"), tint: Theme.windowLit, confirm: true, command: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
            { icon: "restart", label: Lang.t("Redémarrer"), tint: Theme.windowLit, confirm: true, command: ["systemctl", "reboot"] },
            { icon: "power", label: Lang.t("Éteindre"), tint: "#f0705f", confirm: true, command: ["systemctl", "poweroff"] }
        ]

        property real shown: Menus.sessionOpen ? 1 : 0
        property int chosen: 0
        property int armed: -1

        function run(index) {
            const action = actions[index];
            chosen = index;
            if (action.confirm && armed !== index) {
                armed = index;
                disarm.restart();
                return;
            }
            Menus.sessionOpen = false;
            if (action.run)
                action.run();
            else
                launcher.exec(action.command);
        }

        function move(step) {
            armed = -1;
            chosen = (chosen + step + actions.length) % actions.length;
        }

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: shown > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:session"
        WlrLayershell.keyboardFocus: Menus.sessionOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
            target: Menus

            function onSessionOpenChanged() {
                panel.armed = -1;
                panel.chosen = 0;
                if (Menus.sessionOpen)
                    keys.forceActiveFocus();
            }
        }

        // The question stands down by itself if you don't answer
        Timer {
            id: disarm

            interval: 4000
            onTriggered: panel.armed = -1
        }

        Process {
            id: launcher
        }

        Item {
            id: keys

            focus: true
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    Menus.sessionOpen = false;
                    break;
                case Qt.Key_Left:
                case Qt.Key_Up:
                    panel.move(-1);
                    break;
                case Qt.Key_Right:
                case Qt.Key_Down:
                case Qt.Key_Tab:
                    panel.move(1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    panel.run(panel.chosen);
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.launcherShade
            opacity: panel.shown * 0.8

            MouseArea {
                anchors.fill: parent
                onPressed: Menus.sessionOpen = false
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 44
            opacity: panel.shown

            transform: Translate {
                y: (1 - panel.shown) * 20
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: panel.armed >= 0 ? Lang.t("{0}, vraiment ?", panel.actions[panel.armed].label) : Lang.t("Et maintenant ?")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 36
                font.weight: Font.Light
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                Repeater {
                    model: panel.actions

                    Item {
                        id: choice

                        required property var modelData
                        required property int index

                        readonly property bool focused: panel.chosen === index
                        readonly property bool armed: panel.armed === index

                        width: 150
                        height: 196
                        scale: pointer.pressed ? 0.94 : focused ? 1.1 : 1

                        Behavior on scale {
                            NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
                        }

                        HandCard {
                            x: 0
                            width: 150
                            height: 150
                            radius: 0
                            seed: choice.modelData.label
                            tint: choice.modelData.tint
                            ink: choice.focused ? 1 : 0.55
                            rise: choice.armed ? 0.5 : choice.focused ? 0.22 : 0.1
                            alive: panel.visible
                        }

                        Icon {
                            x: 75 - size / 2
                            y: 75 - size / 2
                            name: choice.modelData.icon
                            size: 46
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 168
                            text: choice.armed ? Lang.t("Confirmer") : choice.modelData.label
                            color: choice.focused ? Theme.text : Qt.alpha(Theme.text, 0.7)
                            font.family: Theme.font
                            font.pixelSize: 15
                        }

                        MouseArea {
                            id: pointer

                            width: 150
                            height: 150
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                if (panel.armed !== choice.index)
                                    panel.armed = -1;
                                panel.chosen = choice.index;
                            }
                            onPressed: panel.run(choice.index)
                        }
                    }
                }
            }
        }
    }
}
