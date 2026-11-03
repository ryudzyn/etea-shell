import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar
import qs.modules.bar.menus
import qs.services

// The logbook, laid out like a ship's dashboard: a window onto today's sky up top, the
// month and the focus timer side by side, and what you have to do underneath.
ColumnLayout {
    id: root

    property date month: new Date()
    readonly property int done: Tasks.items.filter(task => task.done).length

    function shift(months) {
        month = new Date(month.getFullYear(), month.getMonth() + months, 1);
    }

    spacing: 12

    DayScene {
        Layout.fillWidth: true
    }

    RowLayout {
        id: pair

        readonly property real tall: Math.max(calendar.implicitHeight, timer.implicitHeight) + 28

        Layout.fillWidth: true
        spacing: 10

        LogCard {
            // Same small start for both, so the extra width splits evenly
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: pair.tall

            ColumnLayout {
                id: calendar

                x: 12
                y: 14
                width: parent.width - 24
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Icon {
                        name: "caret-left"
                        size: 16

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onPressed: root.shift(-1)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale(Config.locale).toString(root.month, "MMMM")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Icon {
                        name: "caret-right"
                        size: 16

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onPressed: root.shift(1)
                        }
                    }
                }

                MonthGrid {
                    Layout.fillWidth: true
                    month: root.month
                    unit: 10.5
                    heading: Theme.windowLit
                }
            }
        }

        LogCard {
            // Same small start for both, so the extra width splits evenly
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: pair.tall

            FocusTimer {
                id: timer

                anchors.centerIn: parent
            }
        }
    }

    LogCard {
        Layout.fillWidth: true
        Layout.preferredHeight: list.implicitHeight + 28

        ColumnLayout {
            id: list

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: Lang.t("Tâches")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                Text {
                    visible: Tasks.items.length > 0
                    text: `${root.done}/${Tasks.items.length}`
                    color: Qt.alpha(Theme.text, 0.55)
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.done > 0
                    text: Lang.t("Ranger les faites")
                    color: Theme.windowLit
                    font.family: Theme.font
                    font.pixelSize: 12

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Tasks.items = Tasks.items.filter(task => !task.done)
                    }
                }
            }

            // How much of the list is done, as a thin line that fills
            Rectangle {
                visible: Tasks.items.length > 0
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                implicitHeight: 3
                radius: 0
                color: Qt.alpha(Theme.windowLit, 0.18)

                Rectangle {
                    width: parent.width * (Tasks.items.length ? root.done / Tasks.items.length : 0)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.windowLit

                    Behavior on width {
                        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
                    }
                }
            }

            // A star you can tick: it lights up once the task is done
            Repeater {
                model: Tasks.items

                Item {
                    id: task

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: label.implicitHeight + 16

                    Rectangle {
                        anchors.fill: parent
                        radius: 0
                        color: Theme.windowLit
                        opacity: pointer.containsMouse ? 0.07 : 0
                    }

                    Star {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        size: 8
                        lit: task.modelData.done
                        animated: false
                        opacity: task.modelData.done ? 1 : 0.5
                    }

                    Text {
                        id: label

                        x: 36
                        width: parent.width - 72
                        anchors.verticalCenter: parent.verticalCenter
                        text: task.modelData.text
                        wrapMode: Text.Wrap
                        font.strikeout: task.modelData.done
                        color: task.modelData.done ? Qt.alpha(Theme.text, 0.45) : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: pointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Tasks.toggle(task.index)
                    }

                    Icon {
                        visible: pointer.containsMouse || remove.containsMouse
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: "close"
                        size: 16

                        MouseArea {
                            id: remove

                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: Tasks.remove(task.index)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: 0
                color: Qt.alpha(Theme.windowLit, 0.08)
                border.width: 1
                border.color: Qt.alpha(Theme.windowLit, entry.activeFocus ? 0.6 : 0.18)

                Icon {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "add"
                    size: 18
                }

                TextInput {
                    id: entry

                    x: 40
                    width: parent.width - 52
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                    onAccepted: {
                        Tasks.add(text);
                        text = "";
                    }

                    Text {
                        visible: entry.text === "" && !entry.activeFocus
                        text: Lang.t("Ajouter une tâche")
                        color: Qt.alpha(Theme.text, 0.5)
                        font: entry.font
                    }
                }
            }
        }
    }
}
