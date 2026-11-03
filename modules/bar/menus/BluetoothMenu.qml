import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.config

// Bluetooth on or off, the devices you already know, and new ones to pair.
ColumnLayout {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var known: Bluetooth.devices.values.filter(device => device.paired || device.connected).sort((a, b) => b.connected - a.connected).slice(0, 7)
    // Devices around that answered the search, those without a name are rarely worth it
    readonly property var nearby: Bluetooth.devices.values.filter(device => !device.paired && !device.connected && device.name && device.name !== device.address.replace(/:/g, "-")).slice(0, 6)
    property bool searching: false // we started the search, so we stop it when the menu closes
    property var pairing: null // the device being paired, so it gets trusted and connected after

    function search() {
        searching = !adapter.discovering;
        adapter.discovering = searching;
    }

    Component.onDestruction: {
        if (searching && adapter)
            adapter.discovering = false;
    }

    readonly property color cardTint: root.adapter?.enabled ? Theme.windowLit : "#a9a4ad"
    readonly property real cardRise: root.adapter?.enabled ? 0.12 : 0.05

    spacing: 6
    width: 320

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: "Bluetooth"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
        }

        MenuSwitch {
            on: root.adapter?.enabled ?? false
            onToggled: root.adapter.enabled = !root.adapter.enabled
        }
    }

    Repeater {
        model: root.adapter?.enabled ? root.known : []

        MenuRow {
            required property var modelData

            Layout.fillWidth: true
            label: modelData.name || modelData.deviceName
            level: modelData.batteryAvailable ? modelData.battery : -1
            active: modelData.connected
            onPicked: modelData.connected ? modelData.disconnect() : modelData.connect()
        }
    }

    Text {
        visible: (root.adapter?.enabled ?? false) && root.known.length === 0
        text: Lang.t("Aucun appareil connu.")
        color: Qt.alpha(Theme.text, 0.6)
        font.family: Theme.font
        font.pixelSize: 12
    }

    MenuRow {
        visible: root.adapter?.enabled ?? false
        Layout.fillWidth: true
        Layout.topMargin: 4
        label: root.adapter?.discovering ? Lang.t("Recherche en cours…") : Lang.t("Chercher des appareils")
        active: root.adapter?.discovering ?? false
        onPicked: root.search()
    }

    // Pairing first, then trusted so it comes back on its own, then connected
    Repeater {
        model: root.adapter?.discovering ? root.nearby : []

        MenuRow {
            required property var modelData

            Layout.fillWidth: true
            label: modelData.name
            detail: modelData.pairing ? Lang.t("Appairage…") : "+"
            onPicked: {
                if (modelData.pairing)
                    return;
                root.pairing = modelData;
                modelData.pair();
            }
        }
    }

    // Once paired the device leaves the list above, so the follow-up lives here
    Connections {
        target: root.pairing

        function onPairedChanged() {
            if (!root.pairing.paired)
                return;
            root.pairing.trusted = true;
            root.pairing.connect();
            root.pairing = null;
        }
    }
}
