import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.bar

// Календар приладом: заголовок, фаза Місяця рядком, сітка місяця.
ColumnLayout {
    id: root

    property real sky: 1080
    property var options: ({})

    spacing: sky * 0.008
    width: sky * 0.26

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    ObsHeader {
        Layout.fillWidth: true
        text: "КАЛЕНДАР · " + Qt.locale(Config.locale).toString(clock.date, "MMMM yyyy").toUpperCase()
        sky: root.sky
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: root.sky * 0.008

        MoonDisc {
            id: moon

            Layout.preferredWidth: Math.round(root.sky * 0.018)
            Layout.preferredHeight: Math.round(root.sky * 0.018)
            at: clock.date
            dark: Qt.alpha(Theme.skyInk, 0.18)
            light: Theme.skyInk
        }

        Text {
            Layout.fillWidth: true
            text: moon.phaseName
            color: Qt.alpha(Theme.skyInk, 0.62)
            font.family: Theme.font
            font.pixelSize: root.sky * 0.0125
        }
    }

    MonthGrid {
        Layout.fillWidth: true
        month: clock.date
        today: clock.date
        unit: root.sky * 0.0125
        ink: Theme.skyInk
        heading: Qt.alpha(Theme.skyInk, 0.6)
    }
}
