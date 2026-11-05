import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.modules.stage
import qs.services

// The one card every right click opens, from where you clicked.
Scope {
    PanelWindow {
        id: panel

        property real reveal: 0
        property var shown: null // stays a little longer than Context.level, so it can fold away
        readonly property bool asking: shown?.input !== undefined

        screen: Context.screen ?? Quickshell.screens[0]
        visible: shown !== null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:context-menu"
        WlrLayershell.keyboardFocus: asking ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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
            active: Context.level !== null
            onCleared: Context.close()
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
            onFinished: panel.shown = null
        }

        Connections {
            target: Context

            function onLevelChanged() {
                fold.stop();
                if (!Context.level) {
                    unfold.stop();
                    fold.restart();
                    return;
                }
                if (panel.shown === null) {
                    panel.reveal = 0;
                    unfold.restart();
                }
                panel.shown = Context.level;
                if (panel.asking) {
                    field.text = panel.shown.input;
                    field.selectAll();
                    field.forceActiveFocus();
                }
            }
        }

        Item {
            id: card

            x: Math.max(14, Math.min(panel.width - width - 14, Context.at.x + 10))
            y: Math.max(14, Math.min(panel.height - height - 14, Context.at.y + 10))
            width: content.width + 40
            height: content.height + 44
            layer.enabled: panel.reveal < 1
            layer.effect: StarMask {
                center: Qt.point(Context.at.x - card.x, Context.at.y - card.y)
                reach: fullReach * panel.reveal
                shine: (1 - panel.reveal) * 0.9
                tint: Theme.windowLit
            }

            HandCard {
                anchors.fill: parent
                seed: "context"
                rise: 0.08
            }

            ColumnLayout {
                id: content

                x: 20
                y: 22
                width: 260
                spacing: 4

                MenuTitle {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    text: panel.shown?.title ?? ""
                }

                MenuRow {
                    visible: Context.levels.length > 1
                    Layout.fillWidth: true
                    label: "‹ " + Lang.t("Retour")
                    onPicked: Context.back()
                }

                Repeater {
                    model: panel.shown?.items ?? []

                    MenuRow {
                        required property var modelData

                        Layout.fillWidth: true
                        label: modelData.label
                        detail: modelData.detail ?? (modelData.input !== undefined ? "›" : "")
                        active: modelData.active ?? false
                        onPicked: Context.pick(modelData)
                    }
                }

                Rectangle {
                    visible: panel.asking
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 0
                    color: Qt.alpha(Theme.windowLit, field.activeFocus ? 0.14 : 0.08)

                    TextInput {
                        id: field

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
                            const done = panel.shown.done;
                            Context.close();
                            done(text.trim());
                        }
                        Keys.onEscapePressed: Context.close()
                    }
                }

                Text {
                    visible: panel.asking
                    text: Lang.t("Entrée pour valider.")
                    color: Qt.alpha(Theme.text, 0.45)
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }
    }
}
