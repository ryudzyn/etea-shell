import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar

// A quick setting. When it's on, its star lights up and the tile fills with colour.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string detail: ""
    property bool on: false
    property bool available: true
    property color tint: Theme.windowLit

    signal toggled()

    Layout.fillWidth: true
    implicitHeight: 84
    opacity: available ? 1 : 0.4
    scale: pointer.pressed ? 0.94 : 1

    Behavior on scale {
        NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
    }

    Entrance {
        item: root
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Qt.alpha(root.tint, root.on ? 0.24 : pointer.containsMouse ? 0.12 : 0.07)
        border.width: 1
        border.color: Qt.alpha(root.tint, root.on ? 0.55 : 0.12)

        Behavior on color {
            ColorAnimation { duration: Theme.normal }
        }
    }

    StarRipple {
        id: ripple
    }

    Item {
        x: 14
        y: 12
        width: 30
        height: 30

        Star {
            anchors.centerIn: parent
            size: 19
            lit: root.on
            animated: false
            opacity: root.on ? 0.55 : 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.normal }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 22
        }
    }

    Column {
        x: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: parent.width - 28

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Text {
            visible: text !== ""
            width: parent.width
            text: root.detail
            elide: Text.ElideRight
            color: Qt.alpha(Theme.text, 0.6)
            font.family: Theme.font
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            ripple.burst(mouse.x, mouse.y);
            root.toggled();
        }
    }
}
