import QtQuick
import Quickshell.Widgets
import qs.config
import qs.modules.bar
import qs.services

// A picture of your own in a porthole frame, the ink line and its stars around it.
Item {
    id: root

    property var options: ({})
    readonly property string image: options?.image ?? ""
    readonly property real ratio: picture.status === Image.Ready ? picture.implicitHeight / Math.max(1, picture.implicitWidth) : 0.66

    implicitWidth: 340
    implicitHeight: image ? (implicitWidth - 24) * ratio + 24 : 150

    HandCard {
        anchors.fill: parent
        seed: "photo"
        rise: 0.05
        alive: Planet.pageEmpty
    }

    ClippingRectangle {
        visible: root.image !== ""
        anchors.fill: parent
        anchors.margins: 12
        radius: 0
        color: "transparent"

        Image {
            id: picture

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: root.width * 2
            source: root.image ? `file://${root.image}` : ""
        }
    }

    Column {
        visible: root.image === ""
        anchors.centerIn: parent
        spacing: 8

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "image"
            size: 30
            tint: Qt.alpha(Theme.text, 0.7)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lang.t("Clic droit pour choisir une image.")
            color: Qt.alpha(Theme.text, 0.7)
            font.family: Theme.font
            font.pixelSize: 13
        }
    }
}
