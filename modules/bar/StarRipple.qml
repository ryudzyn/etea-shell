import QtQuick
import qs.config

// A click answers with a little star bursting open from where it landed.
Item {
    id: root

    anchors.fill: parent
    clip: true
    visible: false

    function burst(x, y) {
        spark.x = x;
        spark.y = y;
        pop.restart();
    }

    Item {
        id: spark

        Star {
            id: star

            x: -size
            y: -size
            size: 60
            lit: true
            animated: false
            opacity: 0
            scale: 0.1
        }
    }

    ParallelAnimation {
        id: pop

        NumberAnimation {
            target: star
            property: "scale"
            from: 0.1
            to: 2.4
            duration: 420
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: star
            property: "opacity"
            from: 0.75
            to: 0
            duration: 420
            easing.type: Easing.OutQuad
        }
    }
}
