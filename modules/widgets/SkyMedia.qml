import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.modules.bar
import qs.modules.bar.menus
import qs.services

// Що грає: заголовок, обкладинка без ефектів, назва, поступ і кнопки.
ColumnLayout {
    id: root

    property real sky: 1080
    readonly property var player: Music.player

    spacing: sky * 0.008
    width: sky * 0.26

    ObsHeader {
        Layout.fillWidth: true
        text: root.player ? "МУЗИКА" : "МУЗИКА · ТИША"
        sky: root.sky
    }

    RowLayout {
        visible: root.player !== null
        Layout.fillWidth: true
        spacing: root.sky * 0.01

        ClippingRectangle {
            visible: cover.status === Image.Ready
            Layout.preferredWidth: root.sky * 0.05
            Layout.preferredHeight: root.sky * 0.05
            radius: 0
            color: "transparent"

            Image {
                id: cover

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(root.sky * 0.1, root.sky * 0.1)
                source: root.player?.trackArtUrl ?? ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.sky * 0.002

            Text {
                Layout.fillWidth: true
                text: root.player?.trackTitle ?? ""
                elide: Text.ElideRight
                color: Theme.skyInk
                font.family: Theme.font
                font.pixelSize: root.sky * 0.0145
            }

            Text {
                Layout.fillWidth: true
                text: root.player?.trackArtist ?? ""
                elide: Text.ElideRight
                color: Qt.alpha(Theme.skyInk, 0.62)
                font.family: Theme.font
                font.pixelSize: root.sky * 0.0125
            }
        }
    }

    MediaProgress {
        entering: false
        visible: known
        Layout.fillWidth: true
        tint: Theme.skyInk
    }

    MediaControls {
        visible: root.player !== null
        Layout.alignment: Qt.AlignRight
        tint: Theme.skyInk
    }
}
