import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Networking
import qs.config

// Wi-Fi on or off, the networks in range, and your VPNs.
ColumnLayout {
    id: root

    readonly property var wifi: Networking.devices.values.find(device => device.networks !== undefined) ?? null
    readonly property var networks: (wifi?.networks.values ?? []).slice().sort((a, b) => b.connected - a.connected || b.signalStrength - a.signalStrength).slice(0, 7)

    readonly property color cardTint: Networking.wifiEnabled ? Theme.windowLit : "#a9a4ad"
    readonly property real cardRise: Networking.wifiEnabled ? 0.12 : 0.05

    property string asking: ""
    property var vpns: [] // { name, uuid, active }, from NetworkManager

    function readVpns() {
        vpnReader.running = true;
    }

    spacing: 6
    width: 320

    // Only scan while someone is looking
    Component.onCompleted: {
        if (wifi)
            wifi.scannerEnabled = true;
        readVpns();
    }

    Process {
        id: vpnReader

        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE,UUID", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.vpns = text.split("\n").map(line => line.split(":")).filter(fields => fields[1] === "vpn" || fields[1] === "wireguard").map(fields => ({ name: fields[0], active: fields[2] === "yes", uuid: fields[3] }))
        }
    }

    // A VPN takes a moment to come up or go down, look again once it has
    Process {
        id: vpnSwitch

        onExited: root.readVpns()
    }
    Component.onDestruction: {
        if (wifi)
            wifi.scannerEnabled = false;
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: "Wi-Fi"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
        }

        MenuSwitch {
            on: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    // A new network, one that needs a password before we can join
    Loader {
        Layout.fillWidth: true
        active: root.asking !== ""
        visible: active

        sourceComponent: WifiPassword {
            network: root.asking
            onFinished: root.asking = ""
        }
    }

    Repeater {
        model: Networking.wifiEnabled ? root.networks : []

        MenuRow {
            required property var modelData

            Layout.fillWidth: true
            label: modelData.name
            level: modelData.signalStrength
            active: modelData.connected
            action: modelData.known ? Lang.t("Oublier") : ""
            onActed: modelData.forget()
            onPicked: {
                if (modelData.connected)
                    modelData.disconnect();
                else if (modelData.known || modelData.security === WifiSecurityType.Open)
                    modelData.connect();
                else
                    root.asking = modelData.name;
            }
        }
    }

    MenuTitle {
        visible: root.vpns.length > 0
        Layout.topMargin: 6
        text: "VPN"
    }

    Repeater {
        model: root.vpns

        MenuRow {
            required property var modelData

            Layout.fillWidth: true
            label: modelData.name
            active: modelData.active
            onPicked: {
                vpnSwitch.command = ["nmcli", "connection", modelData.active ? "down" : "up", "uuid", modelData.uuid];
                vpnSwitch.running = true;
            }
        }
    }
}
