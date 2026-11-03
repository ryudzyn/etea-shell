import QtQuick
import qs.config

// Рядок "назва -- значення" рівними колонками
Item {
    id: root

    property string label: ""
    property string value: ""
    property real sky: 1080

    width: parent.width
    height: name.implicitHeight

    Text {
        id: name
        text: root.label
        color: Qt.alpha(Theme.skyInk, 0.62)
        font.family: Theme.font
        font.pixelSize: root.sky * 0.0125
    }

    Text {
        anchors.right: parent.right
        text: root.value
        color: Theme.skyInk
        font.family: Theme.font
        font.pixelSize: root.sky * 0.0125
        font.features: { "tnum": 1 }
    }
}
