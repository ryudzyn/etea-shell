import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config

// How loud, where the sound goes and where it comes from, and how loud each app is.
ColumnLayout {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var outputs: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio)
    readonly property var inputs: Pipewire.nodes.values.filter(node => !node.isSink && !node.isStream && node.audio)
    // Apps playing sound. One app can open several streams, they share one slider.
    readonly property var streams: Pipewire.nodes.values.filter(node => node.isSink && node.isStream && node.audio)
    readonly property var apps: {
        const found = [];
        for (const stream of streams) {
            const name = stream.properties["application.name"] || stream.name || Lang.t("Sans nom");
            const app = found.find(entry => entry.name === name);
            app ? app.streams.push(stream) : found.push({ name: name, streams: [stream] });
        }
        return found;
    }

    // The horizon climbs with the volume
    readonly property color cardTint: Theme.windowLit
    readonly property real cardRise: 0.05 + Math.min(1, (sink?.audio.volume ?? 0)) * 0.3

    // Device lists stay folded behind the current one, or the menu runs off the screen
    property string unfolded: ""

    spacing: 6
    width: 320

    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node).concat(root.streams)
    }

    MenuTitle {
        text: Lang.t("Sortie")
    }

    MenuSlider {
        Layout.fillWidth: true
        value: root.sink?.audio.volume ?? 0
        maximum: 1.5
        onMoved: value => root.sink.audio.volume = value
    }

    MenuTitle {
        Layout.topMargin: 6
        text: Lang.t("Micro")
    }

    MenuSlider {
        Layout.fillWidth: true
        value: root.source?.audio.volume ?? 0
        maximum: 1.5
        onMoved: value => root.source.audio.volume = value
    }

    MenuTitle {
        Layout.topMargin: 6
        visible: root.outputs.length > 1
        text: Lang.t("Écouter sur")
    }

    MenuRow {
        visible: root.outputs.length > 1
        Layout.fillWidth: true
        label: root.sink?.description || root.sink?.name || ""
        detail: root.unfolded === "outputs" ? "‹" : "›"
        onPicked: root.unfolded = root.unfolded === "outputs" ? "" : "outputs"
    }

    Repeater {
        model: root.unfolded === "outputs" ? root.outputs.filter(node => node !== root.sink) : []

        MenuRow {
            required property var modelData

            Layout.fillWidth: true
            Layout.leftMargin: 14
            label: modelData.description || modelData.name
            onPicked: {
                Pipewire.preferredDefaultAudioSink = modelData;
                root.unfolded = "";
            }
        }
    }

    MenuTitle {
        Layout.topMargin: 6
        visible: root.inputs.length > 1
        text: Lang.t("Enregistrer avec")
    }

    MenuRow {
        visible: root.inputs.length > 1
        Layout.fillWidth: true
        label: root.source?.description || root.source?.name || ""
        detail: root.unfolded === "inputs" ? "‹" : "›"
        onPicked: root.unfolded = root.unfolded === "inputs" ? "" : "inputs"
    }

    Repeater {
        model: root.unfolded === "inputs" ? root.inputs.filter(node => node !== root.source) : []

        MenuRow {
            required property var modelData

            Layout.fillWidth: true
            Layout.leftMargin: 14
            label: modelData.description || modelData.name
            onPicked: {
                Pipewire.preferredDefaultAudioSource = modelData;
                root.unfolded = "";
            }
        }
    }

    MenuTitle {
        Layout.topMargin: 6
        visible: root.apps.length > 0
        text: Lang.t("Applications")
    }

    Repeater {
        model: root.apps

        RowLayout {
            id: app

            required property var modelData

            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 86
                text: app.modelData.name
                elide: Text.ElideRight
                color: Qt.alpha(Theme.text, 0.75)
                font.family: Theme.font
                font.pixelSize: 12
            }

            MenuSlider {
                Layout.fillWidth: true
                value: app.modelData.streams[0]?.audio?.volume ?? 0
                maximum: 1.5
                onMoved: value => {
                    for (const stream of app.modelData.streams) {
                        if (stream.audio)
                            stream.audio.volume = value;
                    }
                }
            }
        }
    }
}
