import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar
import qs.services

// The focus timer as a small card: a ring that fills as the time goes by with a star
// riding its edge, three buttons underneath, and two ways to split your time.
ColumnLayout {
    id: root

    // Your world's light for work, a greener cast of it for the break
    readonly property color tint: Focus.mode === "focus" ? Theme.windowLit : Qt.tint(Theme.windowLit, Qt.alpha("#8fd6b4", 0.55))
    readonly property var presets: [[25, 5], [50, 10]]

    spacing: 10

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Focus.mode === "focus" ? Lang.t("Concentration") : Lang.t("Pause")
        color: root.tint
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 112
        implicitHeight: 112

        Canvas {
            id: ring

            anchors.fill: parent
            renderStrategy: Canvas.Immediate
            onPaint: {
                const g = getContext("2d"), c = width / 2, r = c - 8, start = -Math.PI / 2;
                g.reset();
                g.lineCap = "round";
                g.lineWidth = Theme.ringThickness + 1;
                g.strokeStyle = String(root.tint);
                g.globalAlpha = 0.16;
                g.beginPath();
                g.arc(c, c, r, 0, Math.PI * 2);
                g.stroke();
                g.globalAlpha = 0.95;
                g.beginPath();
                g.arc(c, c, r, start, start + Math.max(0.001, Focus.done) * Math.PI * 2);
                g.stroke();
            }

            Connections {
                target: Focus

                function onLeftChanged() {
                    ring.requestPaint();
                }

                function onModeChanged() {
                    ring.requestPaint();
                }
            }
        }

        Star {
            readonly property real angle: Focus.done * Math.PI * 2 - Math.PI / 2

            x: 56 + 48 * Math.cos(angle) - size
            y: 56 + 48 * Math.sin(angle) - size
            size: 7
            lit: Focus.running
            animated: false
        }

        Text {
            anchors.centerIn: parent
            text: Focus.clock()
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 26
            font.weight: Font.Light
            font.features: { "tnum": 1 }
        }
    }

    // Start or pause, start over, and switch between work and a break
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Repeater {
            model: [
                { icon: Focus.running ? "pause" : "play", strong: true, run: () => Focus.toggle() },
                { icon: "restart", run: () => Focus.reset() },
                { icon: Focus.mode === "focus" ? "coffee" : "timer", run: () => Focus.setMode(Focus.mode === "focus" ? "rest" : "focus") }
            ]

            Rectangle {
                required property var modelData

                width: 36
                height: 36
                radius: 0
                color: Qt.alpha(root.tint, modelData.strong ? (press.containsMouse ? 0.34 : 0.24) : (press.containsMouse ? 0.16 : 0.07))

                Icon {
                    anchors.centerIn: parent
                    name: parent.modelData.icon
                    size: 18
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: parent.modelData.run()
                }
            }
        }
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 6

        Repeater {
            model: root.presets

            Rectangle {
                required property var modelData
                readonly property bool current: Config.focusMinutes === modelData[0] && Config.restMinutes === modelData[1]

                width: label.implicitWidth + 16
                height: 22
                radius: 0
                color: Qt.alpha(root.tint, current ? 0.24 : 0.06)
                border.width: 1
                border.color: Qt.alpha(root.tint, current ? 0.6 : 0.16)

                Text {
                    id: label

                    anchors.centerIn: parent
                    text: `${parent.modelData[0]} · ${parent.modelData[1]}`
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: Focus.usePreset(parent.modelData[0], parent.modelData[1])
                }
            }
        }
    }
}
