import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.modules.bar.menus
import qs.services

// A small porthole that answers the volume, brightness and microphone keys, and says
// which language the keyboard just switched to. Its horizon
// climbs with the level, so you can read it without reading it.
Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    property string kind: "volume"
    property bool awake: false
    property bool showing: false

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property real level: kind === "volume" ? (muted ? 0 : Math.min(1, volume)) : kind === "microphone" ? (micMuted ? 0 : Math.min(1, source?.audio?.volume ?? 0)) : Brightness.value
    readonly property string icon: kind === "keyboard" ? "keyboard" : kind === "brightness" ? "brightness" : kind === "microphone" ? (micMuted ? "microphone-off" : "microphone") : muted ? "speaker-x" : volume > 0.5 ? "speaker-high" : "speaker-low"

    function show(what) {
        if (!awake)
            return;
        kind = what;
        showing = true;
        hide.restart();
    }

    onVolumeChanged: show("volume")
    onMutedChanged: show("volume")
    onMicMutedChanged: show("microphone")

    Connections {
        target: Keyboard

        function onSwitched() {
            root.show("keyboard");
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node)
    }

    // Nothing to announce while everything is still starting up
    Timer {
        running: true
        interval: 1500
        onTriggered: root.awake = true
    }

    Timer {
        id: hide

        interval: 1400
        onTriggered: root.showing = false
    }

    // Brightness keys change it behind our back, the service notices
    Connections {
        target: Brightness

        function onValueChanged() {
            if (Brightness.known)
                root.show("brightness");
        }
    }

    PanelWindow {
        id: panel

        property real shown: root.showing ? 1 : 0

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: shown > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 340
        implicitHeight: 104
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:osd"
        margins.bottom: 54 + (Theme.barOnTop ? 0 : Theme.barReserve)

        anchors {
            bottom: true
        }

        mask: Region {}

        Behavior on shown {
            NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
        }

        Item {
            x: 10
            y: 12 + (1 - panel.shown) * 40
            width: 320
            height: 80
            opacity: Math.min(1, panel.shown)

            HandCard {
                anchors.fill: parent
                seed: root.kind
                tint: Theme.windowLit
                rise: 0.05 + root.level * 0.22
                alive: panel.visible
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 14

                Icon {
                    name: root.icon
                    size: 26
                }

                MenuSlider {
                    visible: root.kind !== "keyboard"
                    Layout.fillWidth: true
                    tint: Theme.text
                    value: root.level
                }

                Text {
                    visible: root.kind === "keyboard"
                    Layout.fillWidth: true
                    text: Keyboard.currentName
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                }

                Text {
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                    text: root.kind === "keyboard" ? Keyboard.code.toUpperCase() : Math.round((root.kind === "volume" ? root.volume : root.level) * 100)
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
            }
        }
    }
}
