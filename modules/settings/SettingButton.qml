import QtQuick
import qs.config
import qs.modules.bar

// A button. It answers a click with a little star, like everything else.
Item {
    id: root

    property string label: ""
    property bool quiet: false

    signal picked()

    implicitWidth: text.implicitWidth + 36
    implicitHeight: 38
    scale: pointer.pressed ? 0.95 : 1

    Behavior on scale {
        NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.windowLit
        opacity: root.quiet ? (pointer.containsMouse ? 0.12 : 0.04) : (pointer.containsMouse ? 0.34 : 0.22)

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }
    }

    Text {
        id: text

        anchors.centerIn: parent
        text: root.label
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    StarRipple {
        id: ripple
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            ripple.burst(mouse.x, mouse.y);
            root.picked();
        }
    }
}
