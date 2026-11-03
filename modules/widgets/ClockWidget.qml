import QtQuick
import Quickshell
import qs.config
import qs.modules.bar
import qs.services

// A celestial dial. Its little sky follows the real time of day from dawn to night, the
// hours are a constellation that draws itself star by star, a planet carries the minutes
// and a comet sweeps round with the seconds.
Item {
    id: root

    property var options: ({}) // its entry in Config.widgets

    readonly property real size: 350
    readonly property real middle: size / 2
    readonly property int hour: clock.date.getHours()
    readonly property int minute: clock.date.getMinutes()
    readonly property real dayTime: hour + minute / 60
    property real seconds: new Date().getSeconds()

    // Dawn, day, dusk, night
    readonly property color skyTone: dayTime < 5 || dayTime >= 21 ? "#8f9cf0" : dayTime < 8 ? "#f59aa0" : dayTime < 17 ? "#ffd08a" : "#f58a5f"
    readonly property real sunHeight: Math.max(0, Math.sin((dayTime - 6) / 12 * Math.PI))

    // Each hour has a fixed place, a touch off the circle, so it reads as a constellation
    readonly property var hours: {
        const wander = [0, 7, -5, 9, -8, 4, -6, 8, -3, 6, -9, 5];
        return wander.map((drift, i) => {
            const angle = i / 12 * Math.PI * 2 - Math.PI / 2, reach = 146 + drift;
            return { x: middle + reach * Math.cos(angle), y: middle + reach * Math.sin(angle), major: i % 3 === 0 };
        });
    }
    readonly property int litHours: hour % 12 + 1

    function point(angle, reach) {
        return Qt.point(middle + reach * Math.cos(angle - Math.PI / 2), middle + reach * Math.sin(angle - Math.PI / 2));
    }

    implicitWidth: size
    implicitHeight: size

    onLitHoursChanged: dial.requestPaint()
    onMinuteChanged: {
        dial.requestPaint();
        pulse.restart();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    FrameAnimation {
        running: Planet.pageEmpty
        onTriggered: {
            const now = new Date();
            root.seconds = now.getSeconds() + now.getMilliseconds() / 1000;
        }
    }

    HandCard {
        anchors.fill: parent
        seed: "clock"
        radius: root.middle
        tint: root.skyTone
        rise: 0.14 + root.sunHeight * 0.3
        alive: Planet.pageEmpty
    }

    // The parts that only change once a minute, so they're drawn once a minute
    Canvas {
        id: dial

        anchors.fill: parent
        renderStrategy: Canvas.Immediate
        onPaint: {
            const g = getContext("2d"), c = root.middle, tone = String(root.skyTone);
            g.reset();
            g.lineCap = "round";
            g.strokeStyle = tone;

            // The minute track, and how far round this hour has come
            const start = -Math.PI / 2, reach = 118;
            g.globalAlpha = 0.18;
            g.lineWidth = Theme.ringThickness;
            g.beginPath();
            g.arc(c, c, reach, 0, Math.PI * 2);
            g.stroke();
            g.globalAlpha = 0.9;
            g.lineWidth = Theme.ringThickness;
            g.beginPath();
            g.arc(c, c, reach, start, start + root.minute / 60 * Math.PI * 2);
            g.stroke();

            // The thread through today's hours so far
            g.lineWidth = 1;
            g.globalAlpha = 0.55;
            g.beginPath();
            root.hours.slice(0, root.litHours).forEach((spot, i) => i ? g.lineTo(spot.x, spot.y) : g.moveTo(spot.x, spot.y));
            g.stroke();
        }
    }

    Repeater {
        model: root.hours

        Star {
            required property var modelData
            required property int index

            readonly property bool reached: index < root.litHours

            x: modelData.x - size
            y: modelData.y - size
            size: (modelData.major ? 8 : 5) * (reached ? 1.25 : 1)
            lit: reached
            animated: false
            opacity: reached ? 1 : 0.32
        }
    }

    // The planet of the minutes
    Item {
        readonly property point spot: root.point(root.minute / 60 * Math.PI * 2, 118)

        x: spot.x
        y: spot.y

        Behavior on x {
            NumberAnimation { duration: 900; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
        }
        Behavior on y {
            NumberAnimation { duration: 900; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
        }

        Rectangle {
            id: planet

            anchors.centerIn: parent
            width: 16
            height: 16
            radius: 0
            color: root.skyTone
        }

        Rectangle {
            id: ring

            anchors.centerIn: parent
            width: 13
            height: 13
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: root.skyTone
            opacity: 0
        }

        // Every new minute sends out a ripple
        ParallelAnimation {
            id: pulse

            NumberAnimation { target: ring; properties: "width,height"; from: 13; to: 54; duration: 900; easing.type: Easing.OutCubic }
            NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 900 }
        }
    }

    // The comet of the seconds, its tail curling along the orbit behind it
    Item {
        anchors.fill: parent
        rotation: root.seconds * 6

        Canvas {
            anchors.fill: parent
            renderStrategy: Canvas.Immediate
            onWidthChanged: requestPaint()
            onPaint: {
                const g = getContext("2d"), c = root.middle, reach = 100;
                g.reset();
                g.lineCap = "round";
                g.strokeStyle = "#ffffff";
                for (let i = 0; i < 26; i++) {
                    const a = -Math.PI / 2 - i * 0.022;
                    g.globalAlpha = (1 - i / 26) * 0.75;
                    g.lineWidth = 2.2 * (1 - i / 26) + 0.3;
                    g.beginPath();
                    g.arc(c, c, reach, a - 0.024, a);
                    g.stroke();
                }
            }
        }

        Star {
            x: root.middle - size
            y: root.middle - 100 - size
            size: 7
            lit: true
            animated: false
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: -4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Config.time(clock.date, { suffix: false })
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 54
            font.weight: Font.Light
            renderType: Text.CurveRendering
        }

        Text {
            visible: root.options?.date !== false
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale(Config.locale).toString(clock.date, Lang.t("ddd d MMM"))
            color: Qt.alpha(Theme.text, 0.8)
            font.family: Theme.font
            font.pixelSize: 15
        }
    }
}
