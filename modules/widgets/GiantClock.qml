import QtQuick
import Quickshell
import qs.config
import qs.modules.bar
import qs.services

// Час як на приладі: місцевий великими цифрами, під ним UTC, зоряний час і юліанська дата.
Column {
    id: root

    property real sky: 1080
    property var options: ({})

    width: sky * 0.26
    spacing: sky * 0.008

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    function pad(n) {
        return String(n).padStart(2, "0");
    }

    readonly property real julian: clock.date.getTime() / 86400000 + 2440587.5
    // Місцевий середній зоряний час; довгота береться з погоди, без неї -- Гринвіч
    readonly property string sidereal: {
        const gmst = 18.697374558 + 24.06570982441908 * (julian - 2451545.0);
        const local = ((gmst + (Weather.spot?.longitude ?? 0) / 15) % 24 + 24) % 24;
        return pad(Math.floor(local)) + ":" + pad(Math.floor(local % 1 * 60));
    }

    ObsHeader {
        text: "ЧАС"
        sky: root.sky
    }

    Text {
        text: Config.time(clock.date, { suffix: false })
        color: Theme.skyInk
        font.family: Theme.font
        font.pixelSize: root.sky * 0.1
        font.weight: Font.Light
        font.letterSpacing: -root.sky * 0.003
        renderType: Text.CurveRendering
    }

    ObsRow {
        label: "UTC"
        value: root.pad(clock.date.getUTCHours()) + ":" + root.pad(clock.date.getUTCMinutes()) + ":" + root.pad(clock.date.getUTCSeconds())
        sky: root.sky
    }
    ObsRow {
        label: "LST"
        value: root.sidereal
        sky: root.sky
    }
    ObsRow {
        label: "JD"
        value: root.julian.toFixed(3)
        sky: root.sky
    }
    ObsRow {
        label: "ДАТА"
        value: Qt.formatDate(clock.date, "yyyy-MM-dd")
        sky: root.sky
    }
}
