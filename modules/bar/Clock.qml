import QtQuick
import Quickshell
import qs.config
import qs.services

// The time up front, the date right next to it. A click opens the calendar.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    SystemClock {
        id: clock

        precision: Config.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Row {
        id: row

        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Config.time(clock.date, { seconds: Config.clockSeconds })
            font.features: { "tnum": 1 }
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.textSize + 6
            font.weight: Font.Medium
        }

        Text {
            visible: Config.dateFormat !== "off"
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale(Config.locale).toString(clock.date, Lang.t(Config.dateFormat === "short" ? "ddd d MMM" : "dddd d MMMM"))
            color: Theme.textSoft
            font.family: Theme.font
            font.pixelSize: Theme.textSize
            font.letterSpacing: 0.3
        }
    }

    Hover {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton)
                RightClick.clock(mapToItem(null, mouse.x, mouse.y), QsWindow.window?.screen ?? null);
            else
                Menus.togglePanel("left");
        }
    }
}
