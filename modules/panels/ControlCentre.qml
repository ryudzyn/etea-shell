import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs.config
import qs.modules.bar
import qs.modules.bar.menus
import qs.modules.notifications
import qs.services

// The control centre: quick settings, sound and light, what's playing and every message.
ColumnLayout {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var battery: UPower.displayDevice
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var network: {
        const wifi = Networking.devices.values.find(device => device.networks !== undefined);
        return wifi?.networks.values.find(network => network.connected) ?? null;
    }
    readonly property var paired: Bluetooth.devices.values.find(device => device.connected) ?? null
    readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    readonly property var profileNames: [Lang.t("Économie"), Lang.t("Équilibré"), "Performance"]
    property var unfolded: [] // apps whose whole stack of signals is open

    spacing: 14

    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node)
    }

    Component.onCompleted: Brightness.refresh()

    // The charge, then the way to the settings and out of the session
    RowLayout {
        Layout.fillWidth: true

        Column {
            Layout.fillWidth: true

            Text {
                text: root.battery?.isLaptopBattery ? `${Math.round(root.battery.percentage * 100)} %` : Config.time(new Date())
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 34
                font.weight: Font.Light
            }

            Text {
                text: UPower.onBattery ? Lang.t("Sur batterie") : Lang.t("Sur secteur")
                color: Qt.alpha(Theme.text, 0.6)
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        Repeater {
            model: [
                { icon: "gear-six", run: () => Menus.settingsOpen = true },
                { icon: "power", run: () => Menus.sessionOpen = true }
            ]

            Item {
                required property var modelData

                Layout.preferredWidth: 42
                Layout.preferredHeight: 42

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: Qt.alpha(Theme.windowLit, pointer.containsMouse ? 0.18 : 0.08)
                }

                Icon {
                    anchors.centerIn: parent
                    name: parent.modelData.icon
                    size: 20
                }

                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: {
                        Menus.closePanel("right");
                        parent.modelData.run();
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 10
        columnSpacing: 10

        QuickTile {
            icon: Networking.wifiEnabled ? "wifi-high" : "wifi-slash"
            label: "Wi-Fi"
            detail: root.network?.name ?? (Networking.wifiEnabled ? Lang.t("Recherche") : Lang.t("Coupé"))
            on: Networking.wifiEnabled
            tint: Theme.windowLit
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }

        QuickTile {
            icon: root.adapter?.enabled ? "bluetooth" : "bluetooth-slash"
            label: "Bluetooth"
            detail: root.paired?.name ?? (root.adapter?.enabled ? Lang.t("Allumé") : Lang.t("Coupé"))
            on: root.adapter?.enabled ?? false
            available: root.adapter !== null
            tint: Theme.windowLit
            onToggled: root.adapter.enabled = !root.adapter.enabled
        }

        QuickTile {
            icon: Notifs.quiet ? "bell-slash" : "bell"
            label: Lang.t("Silence")
            detail: Notifs.quiet ? Lang.t("Activé") : ""
            on: Notifs.quiet
            tint: Theme.windowLit
            onToggled: Notifs.quiet = !Notifs.quiet
        }

        QuickTile {
            icon: "nightlight"
            label: Lang.t("Veilleuse")
            detail: NightLight.on ? `${NightLight.temperature} K` : ""
            on: NightLight.on
            available: NightLight.available
            tint: Theme.windowLit
            onToggled: NightLight.toggle()
        }

        QuickTile {
            icon: root.source?.audio?.muted ? "microphone-off" : "microphone"
            label: Lang.t("Micro")
            detail: root.source?.audio?.muted ? Lang.t("Coupé") : Lang.t("Ouvert")
            on: !(root.source?.audio?.muted ?? true)
            available: root.source?.audio !== undefined
            tint: Theme.windowLit
            onToggled: root.source.audio.muted = !root.source.audio.muted
        }

        QuickTile {
            readonly property int current: Math.max(0, root.profiles.indexOf(PowerProfiles.profile))

            icon: "energy"
            label: Lang.t("Énergie")
            detail: root.profileNames[current]
            on: PowerProfiles.profile !== PowerProfile.Balanced
            tint: Theme.windowLit
            onToggled: {
                const next = root.profiles[(current + 1) % root.profiles.length];
                PowerProfiles.profile = next === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile ? PowerProfile.PowerSaver : next;
            }
        }

        QuickTile {
            icon: "coffee"
            label: Lang.t("Éveillé")
            detail: Wake.on ? Lang.t("Pas de veille") : ""
            on: Wake.on
            tint: Theme.windowLit
            onToggled: Wake.on = !Wake.on
        }

        // Two tools that do something once rather than stay on
        QuickTile {
            icon: "capture"
            label: Lang.t("Capture")
            tint: Theme.windowLit
            onToggled: {
                Menus.closePanel("right");
                Menus.captureOpen = true;
            }
        }

        QuickTile {
            icon: "picker"
            label: Lang.t("Pipette")
            tint: Theme.windowLit
            onToggled: {
                Menus.closePanel("right");
                Picker.pick();
            }
        }
    }

    SliderRow {
        icon: root.sink?.audio?.muted ? "speaker-x" : "speaker-high"
        value: root.sink?.audio?.volume ?? 0
        maximum: 1
        tint: Theme.windowLit
        onMoved: value => root.sink.audio.volume = value
        onIconPressed: root.sink.audio.muted = !root.sink.audio.muted
    }

    SliderRow {
        icon: "brightness"
        value: Brightness.value
        tint: Theme.windowLit
        onMoved: value => Brightness.set(value)
    }

    // What's playing, when something is
    ColumnLayout {
        visible: Music.player !== null
        Layout.fillWidth: true
        spacing: 6

        ContentTint {
            id: colour

            image: Music.player?.trackArtUrl ?? ""
            name: Music.player?.trackTitle ?? "etea"
        }

        SectionTitle {
            text: Lang.t("En écoute")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ClippingRectangle {
                visible: cover.status === Image.Ready
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                radius: 0
                color: "transparent"

                Image {
                    id: cover

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(108, 108)
                    source: Music.player?.trackArtUrl ?? ""
                }
            }

            Column {
                Layout.fillWidth: true

                Text {
                    width: parent.width
                    text: Music.player?.trackTitle ?? ""
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: Music.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    color: Qt.alpha(Theme.text, 0.65)
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }

        MediaProgress {
            Layout.fillWidth: true
            tint: colour.color
        }

        MediaControls {
            Layout.alignment: Qt.AlignHCenter
            tint: colour.color
        }
    }

    SectionTitle {
        text: Notifs.count ? `${Lang.t("Signaux")} · ${Notifs.count}` : Lang.t("Signaux")
        action: Notifs.count ? Lang.t("Tout effacer") : ""
        onActed: Notifs.clear()
    }

    Text {
        visible: Notifs.count === 0
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        text: Lang.t("Aucun signal. Le ciel est calme.")
        color: Qt.alpha(Theme.text, 0.6)
        font.family: Theme.font
        font.pixelSize: 13
    }

    // One stack per app: its two latest, the rest folded behind them
    Repeater {
        model: Notifs.groups.slice(0, 12)

        ColumnLayout {
            id: group

            required property var modelData
            readonly property bool open: root.unfolded.includes(modelData.app)
            readonly property int hidden: modelData.entries.length - 2

            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                visible: group.modelData.entries.length > 1
                Layout.fillWidth: true
                Layout.topMargin: 4

                Text {
                    Layout.fillWidth: true
                    text: `${group.modelData.app || Lang.t("Sans nom")} · ${group.modelData.entries.length}`
                    elide: Text.ElideRight
                    color: Qt.alpha(Theme.text, 0.6)
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Text {
                    text: Lang.t("Effacer")
                    color: Theme.windowLit
                    font.family: Theme.font
                    font.pixelSize: 12

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Notifs.clear(group.modelData.app)
                    }
                }
            }

            Repeater {
                model: group.open ? group.modelData.entries : group.modelData.entries.slice(0, 2)

                NotificationCard {
                    required property var modelData

                    Layout.fillWidth: true
                    width: root.width
                    entry: modelData
                    inJournal: true
                }
            }

            Text {
                visible: group.hidden > 0
                text: group.open ? Lang.t("Replier") : Lang.t("{0} de plus", group.hidden)
                color: Theme.windowLit
                font.family: Theme.font
                font.pixelSize: 12

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onPressed: root.unfolded = group.open ? root.unfolded.filter(app => app !== group.modelData.app) : root.unfolded.concat([group.modelData.app])
                }
            }
        }
    }
}
