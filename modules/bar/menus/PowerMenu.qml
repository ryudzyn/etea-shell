import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.config
import qs.services

// Battery, power profile and screen brightness.
ColumnLayout {
    id: root

    readonly property var battery: UPower.displayDevice

    function timeLeft() {
        const seconds = UPower.onBattery ? battery.timeToEmpty : battery.timeToFull;
        if (!seconds)
            return UPower.onBattery ? Lang.t("Sur batterie") : Lang.t("Sur secteur");
        const hours = Math.floor(seconds / 3600), minutes = Math.round(seconds % 3600 / 60);
        const left = hours ? `${hours} h ${String(minutes).padStart(2, "0")}` : `${minutes} min`;
        return UPower.onBattery ? Lang.t("{0} restantes", left) : Lang.t("Pleine dans {0}", left);
    }

    // The battery is the sun in this card: it sinks as the charge runs out, and turns red
    readonly property real level: battery?.percentage ?? 0
    readonly property color cardTint: !UPower.onBattery ? Theme.windowLit : level < 0.2 ? "#f0705f" : "#ffc98a"
    readonly property real cardRise: 0.06 + level * 0.36

    spacing: 6
    width: 320

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: `${Math.round((root.battery?.percentage ?? 0) * 100)} %`
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 44
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.battery?.isLaptopBattery ? root.timeLeft() : ""
            color: Qt.alpha(Theme.text, 0.6)
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    MenuTitle {
        Layout.topMargin: 6
        text: Lang.t("Énergie")
    }

    Repeater {
        model: [
            { label: Lang.t("Économie"), profile: PowerProfile.PowerSaver },
            { label: Lang.t("Équilibré"), profile: PowerProfile.Balanced },
            { label: "Performance", profile: PowerProfile.Performance }
        ]

        MenuRow {
            required property var modelData

            Layout.fillWidth: true
            visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
            label: modelData.label
            active: PowerProfiles.profile === modelData.profile
            onPicked: PowerProfiles.profile = modelData.profile
        }
    }

    MenuTitle {
        Layout.topMargin: 6
        text: Lang.t("Luminosité")
    }

    MenuSlider {
        Layout.fillWidth: true
        value: Brightness.value
        onMoved: value => Brightness.set(value)
    }
}
