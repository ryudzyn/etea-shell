import QtQuick
import qs.config
import qs.modules.bar
import qs.services

// What you have to do, written on the sky. Each task is a star you can tick, and it
// lights up once it's done, the same list as in the logbook.
Column {
    id: root

    property real sky: 1080
    property var options: ({})
    readonly property int most: 7

    spacing: sky * 0.008
    width: sky * 0.26

    ObsHeader {
        text: "ЗАВДАННЯ" + (Tasks.items.length ? " · " + Tasks.items.filter(task => !task.done).length : "")
        sky: root.sky
    }

    Repeater {
        model: Tasks.items.slice(0, root.most)

        Item {
            id: task

            required property var modelData
            required property int index

            width: root.width
            height: label.implicitHeight + root.sky * 0.005

            Rectangle {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                width: root.sky * 0.009
                height: width
                color: task.modelData.done ? Theme.skyInk : "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.skyInk, 0.6)
            }

            Text {
                id: label

                x: root.sky * 0.018
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                text: task.modelData.text
                elide: Text.ElideRight
                font.strikeout: task.modelData.done
                color: task.modelData.done ? Qt.alpha(Theme.skyInk, 0.45) : Theme.skyInk
                font.family: Theme.font
                font.pixelSize: root.sky * 0.0135
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: Tasks.toggle(task.index)
            }
        }
    }

    Text {
        visible: Tasks.items.length > root.most
        text: `+ ${Tasks.items.length - root.most}`
        color: Qt.alpha(Theme.skyInk, 0.6)
        font.family: Theme.font
        font.pixelSize: root.sky * 0.0125
    }

    Text {
        visible: Tasks.items.length === 0
        text: "порожньо · Super+A"
        color: Qt.alpha(Theme.skyInk, 0.62)
        font.family: Theme.font
        font.pixelSize: root.sky * 0.0125
    }
}
