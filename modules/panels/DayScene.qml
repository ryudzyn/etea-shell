import QtQuick
import Quickshell
import qs.config
import qs.modules.bar
import qs.services

// A window onto today's sky: the sun climbs its arc from sunrise to sunset, then the moon
// takes the night. The light is your world's own: its sky by day, its low glow at both
// ends, its light at night.
Item {
    id: root

    property bool alive: visible

    readonly property real now: clock.date.getTime()
    readonly property real rise: Weather.sunrise.getTime()
    readonly property real set: Weather.sunset.getTime()
    readonly property bool day: now >= rise && now < set
    // How far along its arc the sun is by day, or the moon by night
    readonly property real along: {
        if (day)
            return (now - rise) / (set - rise);
        const night = 86400000 - (set - rise);
        return (((now - set) % 86400000 + 86400000) % 86400000) / night;
    }
    readonly property bool edge: day && (along < 0.12 || along > 0.88) // dawn and dusk
    readonly property color light: !day ? Theme.windowLit : edge ? Theme.skyLow : Theme.skyMid
    readonly property var weather: Weather.look(Weather.code, Weather.day)

    implicitHeight: 172

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // The logbook would like the weather too, while it's open
    onAliveChanged: alive ? Weather.join() : Weather.leave()
    Component.onCompleted: {
        if (alive)
            Weather.join();
    }
    Component.onDestruction: {
        if (alive)
            Weather.leave();
    }

    HandCard {
        anchors.fill: parent
        seed: "day"
        tint: root.light
        rise: root.day ? 0.18 + 0.12 * Math.sin(Math.PI * root.along) : 0.1
        radius: 0
        alive: root.alive

        Behavior on tint {
            ColorAnimation { duration: 1200 }
        }
    }

    // The sun, or the moon, on its arc above the hills
    Item {
        id: body

        readonly property real arc: root.height * 0.5
        readonly property real horizon: root.height * 0.82

        x: 26 + (root.width - 52) * root.along - width / 2
        y: horizon - Math.sin(Math.PI * root.along) * arc - height / 2
        width: 52
        height: 52

        Rectangle {
            visible: root.day
            anchors.centerIn: parent
            width: 52
            height: 52
            radius: 0
            color: Qt.alpha(root.edge ? "#ffb38a" : "#ffe2a8", 0.16)
        }

        Rectangle {
            visible: root.day
            anchors.centerIn: parent
            width: 30
            height: 30
            radius: 0
            color: Qt.alpha(root.edge ? "#ffc9a0" : "#fff1cf", 0.35)
        }

        Rectangle {
            visible: root.day
            anchors.centerIn: parent
            width: 16
            height: 16
            radius: 0
            color: root.edge ? "#ffd2ad" : "#fff6e0"
        }

        MoonDisc {
            visible: !root.day
            anchors.centerIn: parent
            width: 24
            height: 24
            at: clock.date
        }
    }

    Column {
        x: 22
        y: 18
        spacing: 0

        Text {
            text: Config.time(clock.date)
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 34
            font.weight: Font.Light
        }

        Text {
            text: Qt.locale(Config.locale).toString(clock.date, Lang.t("dddd d MMMM"))
            color: Qt.alpha(Theme.text, 0.75)
            font.family: Theme.font
            font.pixelSize: 13
        }
    }

    Column {
        visible: Weather.known
        anchors.right: parent.right
        anchors.rightMargin: 22
        y: 20
        spacing: 2

        Row {
            anchors.right: parent.right
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.weather.icon
                size: 20
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(Weather.temperature)}°`
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 20
            }
        }

        Text {
            anchors.right: parent.right
            text: `↑ ${Config.time(Weather.sunrise)}   ↓ ${Config.time(Weather.sunset)}`
            color: Qt.alpha(Theme.text, 0.6)
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
}
