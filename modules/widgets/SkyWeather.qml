import QtQuick
import qs.config
import qs.modules.bar
import qs.services

// Погода таблицею: зараз і найближчі години.
Column {
    id: root

    property real sky: 1080
    property var options: ({})
    readonly property var now: Weather.look(Weather.code, Weather.day)

    width: sky * 0.26
    spacing: sky * 0.008

    ObsHeader {
        text: "ПОГОДА" + (Weather.place ? " · " + Weather.place.toUpperCase() : "")
        sky: root.sky
    }

    Row {
        spacing: root.sky * 0.016

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.known ? `${Math.round(Weather.temperature)}°` : "–"
            color: Theme.skyInk
            font.family: Theme.font
            font.pixelSize: root.sky * 0.05
            font.weight: Font.Light
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.known ? root.now.label : Weather.failed || "…"
            color: Qt.alpha(Theme.skyInk, 0.75)
            font.family: Theme.font
            font.pixelSize: root.sky * 0.0125
        }
    }

    Row {
        visible: Weather.known
        width: parent.width

        Repeater {
            model: Weather.hours.slice(0, 5)

            Column {
                required property var modelData
                width: parent.width / 5

                Text {
                    text: Config.time(parent.modelData.time, { suffix: false })
                    color: Qt.alpha(Theme.skyInk, 0.62)
                    font.family: Theme.font
                    font.pixelSize: root.sky * 0.0105
                }

                Text {
                    text: Math.round(parent.modelData.temperature) + "°"
                    color: Theme.skyInk
                    font.family: Theme.font
                    font.pixelSize: root.sky * 0.0145
                }
            }
        }
    }
}
