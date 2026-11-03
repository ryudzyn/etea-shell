import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar
import qs.services

// Your to-do list in a porthole. Each task is a star you can tick, the same list as in
// the logbook, and the horizon rises as the list gets done.
Item {
    id: root

    property var options: ({})
    readonly property int most: 7
    readonly property int remaining: Tasks.items.filter(task => !task.done).length

    implicitWidth: 320
    implicitHeight: content.implicitHeight + 50

    HandCard {
        anchors.fill: parent
        seed: "tasks"
        tint: "#a8d8c0"
        rise: Tasks.items.length ? 0.06 + 0.3 * (1 - root.remaining / Tasks.items.length) : 0.06
        alive: Planet.pageEmpty
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 2

        Text {
            Layout.bottomMargin: 6
            text: Tasks.items.length ? `${Lang.t("Tâches")} · ${root.remaining}` : Lang.t("Tâches")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 17
        }

        Repeater {
            model: Tasks.items.slice(0, root.most)

            Item {
                id: task

                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: label.implicitHeight + 12

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: Theme.windowLit
                    opacity: pointer.containsMouse ? 0.08 : 0
                }

                Star {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    size: 7
                    lit: task.modelData.done
                    animated: false
                    opacity: task.modelData.done ? 1 : 0.5
                }

                Text {
                    id: label

                    x: 28
                    width: parent.width - 36
                    anchors.verticalCenter: parent.verticalCenter
                    text: task.modelData.text
                    elide: Text.ElideRight
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
            }
        }

        Text {
            visible: Tasks.items.length > root.most
            text: `+ ${Tasks.items.length - root.most}`
            color: Qt.alpha(Theme.text, 0.6)
            font.family: Theme.font
            font.pixelSize: 12
        }

        Text {
            visible: Tasks.items.length === 0
            Layout.fillWidth: true
            text: Lang.t("Rien à faire. Le ciel est à toi.")
            wrapMode: Text.WordWrap
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
        }

        Text {
            visible: Tasks.items.length === 0
            Layout.fillWidth: true
            text: Lang.t("Ajoute-en dans le panneau de gauche, Super + A.")
            wrapMode: Text.WordWrap
            color: Qt.alpha(Theme.text, 0.6)
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
