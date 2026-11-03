import QtQuick
import qs.config

// Заголовок віджета: дрібний розріджений підпис над тонкою лінією
Column {
    id: root

    property string text: ""
    property real sky: 1080

    width: parent.width
    spacing: sky * 0.006

    Text {
        text: root.text
        color: Qt.alpha(Theme.skyInk, 0.62)
        font.family: Theme.font
        font.pixelSize: root.sky * 0.011
        font.letterSpacing: root.sky * 0.0016
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.alpha(Theme.skyInk, 0.28)
    }
}
