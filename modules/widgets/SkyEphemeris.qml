import QtQuick
import Quickshell
import qs.config
import qs.services
import "sky.js" as Sky

// Що зараз на небі в місці спостереження: висота й азимут, те що нижче горизонту -- тьмяно.
Column {
    id: root

    property real sky: 1080
    property var options: ({})
    readonly property var spot: Weather.spot
    readonly property var rows: spot ? Sky.bodies(clock.date, spot.latitude, spot.longitude) : []

    width: sky * 0.26
    spacing: sky * 0.005

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function degrees(value, digits) {
        const sign = value < 0 ? "−" : "+";
        return sign + Math.abs(value).toFixed(1).padStart(digits, "0") + "°";
    }

    ObsHeader {
        text: "НЕБО" + (root.spot ? " · " + Math.abs(root.spot.latitude).toFixed(1) + "° " + (root.spot.latitude < 0 ? "S" : "N") : "")
        sky: root.sky
    }

    Row {
        width: parent.width

        Text {
            width: parent.width * 0.5
            text: "ОБ'ЄКТ"
            color: Qt.alpha(Theme.skyInk, 0.62)
            font.family: Theme.font
            font.pixelSize: root.sky * 0.0105
        }
        Text {
            width: parent.width * 0.25
            horizontalAlignment: Text.AlignRight
            text: "ВИС."
            color: Qt.alpha(Theme.skyInk, 0.62)
            font.family: Theme.font
            font.pixelSize: root.sky * 0.0105
        }
        Text {
            width: parent.width * 0.25
            horizontalAlignment: Text.AlignRight
            text: "АЗ."
            color: Qt.alpha(Theme.skyInk, 0.62)
            font.family: Theme.font
            font.pixelSize: root.sky * 0.0105
        }
    }

    Repeater {
        model: root.rows

        Row {
            id: row
            required property var modelData
            readonly property color ink: modelData.alt > 0 ? Theme.skyInk : Qt.alpha(Theme.skyInk, 0.42)
            width: parent.width

            Text {
                width: parent.width * 0.5
                text: row.modelData.name
                color: row.ink
                font.family: Theme.font
                font.pixelSize: root.sky * 0.0125
            }
            Text {
                width: parent.width * 0.25
                horizontalAlignment: Text.AlignRight
                text: root.degrees(row.modelData.alt, 4)
                color: row.ink
                font.family: Theme.font
                font.pixelSize: root.sky * 0.0125
            }
            Text {
                width: parent.width * 0.25
                horizontalAlignment: Text.AlignRight
                text: String(Math.round(row.modelData.az)).padStart(3, "0") + "°"
                color: row.ink
                font.family: Theme.font
                font.pixelSize: root.sky * 0.0125
            }
        }
    }

    Text {
        visible: !root.spot
        text: "немає координат"
        color: Qt.alpha(Theme.skyInk, 0.62)
        font.family: Theme.font
        font.pixelSize: root.sky * 0.0125
    }
}
