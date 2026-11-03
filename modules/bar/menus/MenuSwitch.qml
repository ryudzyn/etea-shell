import QtQuick
import qs.config
import qs.modules.bar
import qs.services

// On or off. The star slides across and lights up.
Item {
    id: root

    property bool on: false

    signal toggled()

    implicitWidth: 44
    implicitHeight: 24

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 2
        radius: 0
        color: Qt.alpha(Menus.tint, root.on ? 0.8 : 0.22)
    }

    Star {
        x: (root.on ? parent.width - 8 : 8) - size
        y: parent.height / 2 - size
        size: 8
        lit: root.on
        animated: false

        Behavior on x {
            NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: root.toggled()
    }
}
