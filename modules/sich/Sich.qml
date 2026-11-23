import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Січ -- голосовий асистент (Nebula Hub; клієнт `sich` у nebula-config). Маленький супутник
// вилітає по дузі з-за правого краю й зависає в правому нижньому куті:
//   слухає  -- на антені блимає вогник, від неї розходяться кола;
//   думає   -- сонячні панелі обертаються навколо корпусу, поруч три крапки;
//   відповідає -- бульбашка зліва: почуте (дрібно) і відповідь;
// потім сам відлітає. Керується лише ззовні:
//   etea-ipc sich listening | think "<почуте>" | answer "<почуте>" "<відповідь>" | hide
// Вікно не ловить мишу (порожня маска) і не займає місця.
Scope {
    id: root

    property string mode: "" // "", listen, think, answer
    property string heard: ""
    property string reply: ""
    property real flight: 0 // 0 -- за краєм екрана, 1 -- на місці

    function arrive(what) {
        mode = what;
        leave.stop();
        flight = 1;
    }

    IpcHandler {
        target: "sich"

        function listening(): void { // не listen: це слово займає сам `qs ipc`
            root.heard = "";
            root.reply = "";
            root.arrive("listen");
            root.guard.restart();
        }

        function think(heard: string): void {
            root.heard = heard;
            root.reply = "";
            root.arrive("think");
            root.guard.restart();
        }

        function answer(heard: string, reply: string): void {
            root.heard = heard;
            root.reply = reply;
            root.arrive("answer");
            root.guard.stop();
            // читати встигнути: 4 с + трохи на кожен знак, не довше 16 с
            leave.interval = Math.min(16000, 4000 + 55 * (heard.length + reply.length));
            leave.restart();
        }

        function hide(): void {
            root.goAway();
        }
    }

    function goAway() {
        guard.stop();
        leave.stop();
        flight = 0;
    }

    property Timer guard: Timer { // клієнт упав посеред розмови -- не висіти вічно
        interval: 60000
        onTriggered: root.goAway()
    }

    Timer {
        id: leave

        onTriggered: root.goAway()
    }

    Behavior on flight {
        NumberAnimation {
            duration: root.flight > 0.5 ? 650 : 900
            easing.type: root.flight > 0.5 ? Easing.InCubic : Easing.OutCubic
        }
    }

    onFlightChanged: if (flight === 0) mode = ""

    PanelWindow {
        id: panel

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.flight > 0.001
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 780
        implicitHeight: 300
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:sich"
        margins.right: 24
        margins.bottom: 24 + (Theme.barOnTop ? 0 : Theme.barReserve)

        anchors {
            right: true
            bottom: true
        }

        mask: Region {}

        // Дуга польоту: квадратична крива від-за правого краю зверху до місця спочинку.
        readonly property real restX: width - 130
        readonly property real restY: height - 90
        readonly property real t: root.flight
        readonly property point from: Qt.point(width + 120, restY - 230)
        readonly property point bend: Qt.point(restX + 40, restY - 210)

        Item {
            id: sat

            width: 0
            height: 0
            x: (1 - panel.t) * (1 - panel.t) * panel.from.x + 2 * (1 - panel.t) * panel.t * panel.bend.x + panel.t * panel.t * panel.restX
            y: (1 - panel.t) * (1 - panel.t) * panel.from.y + 2 * (1 - panel.t) * panel.t * panel.bend.y + panel.t * panel.t * panel.restY
            rotation: -18 * (1 - panel.t) + bob.angle
            scale: 1.6

            // на місці ледь гойдається, як на орбіті
            QtObject {
                id: bob

                property real phase: 0
                readonly property real angle: Math.sin(phase) * 3
                property NumberAnimation run: NumberAnimation {
                    target: bob
                    property: "phase"
                    from: 0
                    to: Math.PI * 2
                    duration: 5200
                    loops: Animation.Infinite
                    running: panel.visible
                }
            }

            // кола від антени, поки слухає
            Repeater {
                model: 3

                Rectangle {
                    id: ring

                    required property int index
                    property real p: 0

                    x: -4 - width / 2
                    y: -40 - height / 2
                    width: 10 + p * 70
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.windowLit
                    opacity: root.mode === "listen" ? (1 - p) * 0.8 : 0

                    NumberAnimation on p {
                        from: 0
                        to: 1
                        duration: 1800
                        loops: Animation.Infinite
                        running: root.mode === "listen"
                    }

                    Component.onCompleted: p = index / 3
                }
            }

            // сонячні панелі: «обертаються» навколо корпусу, поки думає
            Repeater {
                model: [-1, 1]

                Item {
                    id: wing

                    required property var modelData

                    x: modelData < 0 ? -70 : 18
                    y: -9
                    width: 52
                    height: 18

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0.07, 0.10, 0.16, 0.92)
                        border.width: 1
                        border.color: Theme.windowLit

                        // сітка комірок
                        Row {
                            anchors.fill: parent
                            Repeater {
                                model: 4

                                Rectangle {
                                    width: 13
                                    height: 18
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                }
                            }
                        }

                        transform: Scale {
                            id: spin

                            origin.x: wing.width / 2
                            origin.y: wing.height / 2
                            property real turn: 0
                            yScale: Math.abs(Math.cos(turn)) * 0.85 + 0.15

                            NumberAnimation on turn {
                                from: 0
                                to: Math.PI
                                duration: 1100
                                loops: Animation.Infinite
                                running: root.mode === "think"
                                onRunningChanged: if (!running) spin.turn = 0
                            }
                        }
                    }

                    // штанга до корпусу
                    Rectangle {
                        x: wing.modelData < 0 ? parent.width : -18
                        y: parent.height / 2
                        width: 18
                        height: 1
                        color: Theme.textSoft
                    }
                }
            }

            // корпус
            Rectangle {
                x: -14
                y: -14
                width: 28
                height: 28
                color: Qt.rgba(0.85, 0.82, 0.78, 0.95)
                border.width: 1
                border.color: Theme.windowLit

                Rectangle { // «вікно» приладів
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    color: Qt.rgba(0.08, 0.10, 0.14, 1)
                    border.width: 1
                    border.color: Theme.windowLit
                }
            }

            // антена
            Rectangle {
                x: -1
                y: -38
                width: 1
                height: 24
                color: Theme.textSoft
                rotation: 0
            }

            Rectangle {
                id: tip

                x: -4
                y: -44
                width: 7
                height: 7
                radius: 3.5
                color: root.mode === "listen" ? "#ff5a4a" : Theme.windowLit
                opacity: 1

                SequentialAnimation on opacity {
                    running: root.mode === "listen"
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) tip.opacity = 1
                    NumberAnimation { to: 0.15; duration: 380 }
                    NumberAnimation { to: 1; duration: 380 }
                }
            }

            // три крапки, поки думає
            Row {
                x: -16
                y: 26
                spacing: 6
                visible: root.mode === "think"

                Repeater {
                    model: 3

                    Rectangle {
                        id: dot

                        required property int index

                        width: 5
                        height: 5
                        color: Theme.text

                        SequentialAnimation on opacity {
                            running: root.mode === "think"
                            loops: Animation.Infinite
                            PauseAnimation { duration: dot.index * 200 }
                            NumberAnimation { to: 0.15; duration: 300 }
                            NumberAnimation { to: 1; duration: 300 }
                            PauseAnimation { duration: (2 - dot.index) * 200 }
                        }
                    }
                }
            }
        }

        // бульбашка зліва від супутника
        Item {
            id: bubble

            readonly property bool wanted: (root.mode === "answer" && (root.reply !== "" || root.heard !== ""))
                                           || (root.mode === "think" && root.heard !== "")
            width: 380
            height: card.implicitHeight + 28
            x: sat.x - 150 - width
            y: Math.max(0, sat.y - height / 2)
            opacity: wanted && panel.t > 0.95 ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: Theme.normal }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.03, 0.04, 0.07, 0.86)
                border.width: 1
                border.color: Theme.windowLit
            }

            // хвостик до супутника
            Rectangle {
                x: parent.width
                y: parent.height / 2
                width: 34
                height: 1
                color: Theme.windowLit
                opacity: 0.7
            }

            ColumnLayout {
                id: card

                x: 16
                y: 14
                width: parent.width - 32
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    visible: root.heard !== ""
                    text: "«" + root.heard + "»"
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    color: Theme.textSoft
                    opacity: 0.75
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.reply !== ""
                    text: root.reply
                    wrapMode: Text.Wrap
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                }

                Text {
                    text: "СІЧ"
                    color: Theme.windowLit
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.letterSpacing: 3
                }
            }
        }
    }
}
