import QtQuick
import QtQuick.Shapes
import qs.config

// The four-pointed star, the one you keep running into all over ETEA.
Item {
    id: root

    property real size: 8
    property bool lit: false
    property bool appear: true
    property bool animated: true // false for stars that are simply there, like on a frame

    width: size * 2
    height: size * 2
    scale: animated ? 0 : 1

    onAppearChanged: {
        if (!animated)
            return;
        birth.stop();
        if (appear)
            birth.start();
        else
            scale = 0;
    }

    Component.onCompleted: {
        if (appear && animated)
            birth.start();
    }

    // It's born a little too big, then settles back down
    SequentialAnimation {
        id: birth

        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: Theme.fast
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: Theme.normal
            easing.type: Easing.OutCubic
        }
    }

    // The halo, which is what really sells the shine
    Shape {
        id: halo
        visible: false

        readonly property real radius: root.size * 2.4

        anchors.centerIn: parent
        width: radius * 2
        height: radius * 2
        opacity: root.lit ? 1 : 0
        preferredRendererType: Shape.CurveRenderer

        Behavior on opacity {
            NumberAnimation { duration: Theme.normal }
        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: halo.radius
                centerY: halo.radius
                focalX: centerX
                focalY: centerY
                centerRadius: halo.radius

                GradientStop { position: 0; color: Qt.alpha(Theme.starGlow, 0.8) }
                GradientStop { position: 0.4; color: Qt.alpha(Theme.starGlow, 0.24) }
                GradientStop { position: 1; color: Qt.alpha(Theme.starGlow, 0) }
            }

            PathAngleArc {
                centerX: halo.radius
                centerY: halo.radius
                radiusX: halo.radius
                radiusY: halo.radius
                sweepAngle: 360
            }
        }
    }

    // Позначка: дрібна -- суцільний квадрат, велика -- тонка рамка навколо вмісту
    Rectangle {
        readonly property bool frame: root.size > 12
        readonly property real side: Math.round(frame ? root.size * 1.7 : root.size)
        anchors.centerIn: parent
        width: side
        height: side
        color: frame ? "transparent" : parent.ink
        border.width: frame ? 1 : 0
        border.color: parent.ink
        opacity: root.lit ? 1 : 0.55

        Behavior on opacity {
            NumberAnimation { duration: Theme.normal }
        }
    }

    readonly property color ink: lit ? Theme.windowLit : Theme.starAsleep
}
