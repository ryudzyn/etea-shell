import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.modules.stage
import qs.services

// A right click on a widget: its size, its options, and a way to put it away.
Scope {
    // The picture for the photo frame
    Process {
        id: picker

        command: ["sh", "-c", 'if command -v kdialog >/dev/null; then kdialog --title "$1" --getopenfilename "$HOME" "*.png *.jpg *.jpeg *.webp"; else zenity --file-selection --title "$1"; fi', "sh", Lang.t("Une image pour le ciel")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    Desk.update("photo", { image: text.trim() });
            }
        }
    }

    PanelWindow {
        id: panel

        property real reveal: 0
        property string shown: "" // stays a little longer than Desk.menuFor, so it can fold away
        readonly property var widget: shown ? Desk.entry(shown) : null

        screen: Desk.menuScreen ?? Quickshell.screens[0]
        visible: shown !== ""
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:desk-menu"
        // Only the weather has something to type, its city
        WlrLayershell.keyboardFocus: shown === "weather" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: card
        }

        HyprlandFocusGrab {
            windows: [panel]
            active: Desk.menuFor !== ""
            onCleared: Desk.menuFor = ""
        }

        NumberAnimation {
            id: unfold

            target: panel
            property: "reveal"
            to: 1
            duration: Theme.cardOpen
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: fold

            target: panel
            property: "reveal"
            to: 0
            duration: Theme.cardOpen * 0.8
            easing.type: Easing.OutQuad
            onFinished: panel.shown = ""
        }

        Connections {
            target: Desk

            function onMenuForChanged() {
                fold.stop();
                if (Desk.menuFor) {
                    panel.reveal = 0;
                    panel.shown = Desk.menuFor;
                    city.text = Desk.entry("weather").city ?? "";
                    unfold.restart();
                } else {
                    unfold.stop();
                    fold.restart();
                }
            }
        }

        // Opens from where you clicked, and stays on screen
        Item {
            id: card

            x: Math.max(14, Math.min(panel.width - width - 14, Desk.menuAt.x + 10))
            y: Math.max(14, Math.min(panel.height - height - 14, Desk.menuAt.y + 10))
            width: content.width + 40
            height: content.height + 44
            layer.enabled: panel.reveal < 1
            layer.effect: StarMask {
                center: Qt.point(Desk.menuAt.x - card.x, Desk.menuAt.y - card.y)
                reach: fullReach * panel.reveal
                shine: (1 - panel.reveal) * 0.9
                tint: Theme.windowLit
            }

            HandCard {
                anchors.fill: parent
                seed: `desk-${panel.shown}`
                rise: 0.08
            }

            ColumnLayout {
                id: content

                x: 20
                y: 22
                width: 260
                spacing: 4

                MenuTitle {
                    Layout.bottomMargin: 4
                    text: panel.widget ? Desk.label(panel.shown) : ""
                }

                // A widget's own card
                ColumnLayout {
                    visible: panel.widget !== null
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: Lang.t("Taille")
                        color: Qt.alpha(Theme.text, 0.6)
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    MenuSlider {
                        Layout.fillWidth: true
                        value: (Desk.size(panel.shown) - 0.5) / 1.1
                        onMoved: value => Desk.update(panel.shown, { size: Math.round((0.5 + value * 1.1) * 100) / 100 })
                    }

                    MenuRow {
                        visible: panel.shown === "clock"
                        Layout.fillWidth: true
                        label: Lang.t("Date")
                        active: panel.widget?.date !== false
                        onPicked: Desk.update("clock", { date: panel.widget?.date === false })
                    }

                    Repeater {
                        model: panel.shown === "system" ? [{ id: "cpu", label: Lang.t("Processeur") }, { id: "memory", label: Lang.t("Mémoire") }, { id: "network", label: Lang.t("Débit réseau") }, { id: "temperature", label: Lang.t("Chaleur") }] : []

                        MenuRow {
                            required property var modelData
                            readonly property var readings: panel.widget?.readings ?? ["cpu", "memory", "network", "temperature"]

                            Layout.fillWidth: true
                            label: modelData.label
                            active: readings.includes(modelData.id)
                            // One reading at least, or the widget would be an empty space
                            onPicked: {
                                const next = active ? readings.filter(id => id !== modelData.id) : readings.concat([modelData.id]);
                                if (next.length)
                                    Desk.update("system", { readings: ["cpu", "memory", "network", "temperature"].filter(id => next.includes(id)) });
                            }
                        }
                    }

                    MenuRow {
                        visible: panel.shown === "photo"
                        Layout.fillWidth: true
                        label: panel.widget?.image ? Lang.t("Changer d'image") : Lang.t("Choisir une image")
                        onPicked: {
                            Desk.menuFor = "";
                            picker.running = true;
                        }
                    }

                    // Where to look at the sky. Empty means wherever the connection says you are.
                    ColumnLayout {
                        visible: panel.shown === "weather"
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: Lang.t("Ville")
                            color: Qt.alpha(Theme.text, 0.6)
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 0
                            color: Qt.alpha(Theme.windowLit, city.activeFocus ? 0.14 : 0.08)

                            TextInput {
                                id: city

                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                selectionColor: Qt.alpha(Theme.windowLit, 0.4)
                                font.family: Theme.font
                                font.pixelSize: 13
                                clip: true
                                onAccepted: {
                                    Desk.update("weather", { city: text.trim() });
                                    Desk.menuFor = "";
                                }
                                Keys.onEscapePressed: Desk.menuFor = ""
                            }

                            Text {
                                visible: city.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                text: Lang.t("Automatique, selon ta connexion")
                                color: Qt.alpha(Theme.text, 0.4)
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                        }

                        Text {
                            text: Lang.t("Entrée pour valider.")
                            color: Qt.alpha(Theme.text, 0.45)
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }

                    MenuRow {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        label: Lang.t("Retirer du ciel")
                        onPicked: {
                            Desk.remove(panel.shown);
                            Desk.menuFor = "";
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    text: Lang.t("Super + glisser pour déplacer, Super + molette pour la taille.")
                    wrapMode: Text.WordWrap
                    color: Qt.alpha(Theme.text, 0.45)
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }
    }
}
