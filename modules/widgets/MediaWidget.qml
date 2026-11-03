import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.modules.bar
import qs.modules.bar.menus
import qs.services

// What's playing, and everything you need to steer it. The card takes on the colour of
// the cover, the music dances across it, and pausing leaves it right where it is.
Item {
    id: root

    readonly property var player: Music.player

    implicitWidth: 390
    implicitHeight: player ? 256 : 110

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.cardOpen; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
    }

    ContentTint {
        id: colour

        image: root.player?.trackArtUrl ?? ""
        name: root.player?.trackTitle ?? "etea"
    }

    HandCard {
        anchors.fill: parent
        seed: "media"
        tint: root.player ? colour.color : "#a9a4ad"
        rise: 0.06
        alive: Planet.pageEmpty
    }

    Text {
        visible: !root.player
        anchors.centerIn: parent
        text: Lang.t("Silence radio.")
        color: Qt.alpha(Theme.text, 0.7)
        font.family: Theme.font
        font.pixelSize: 17
    }

    ColumnLayout {
        visible: root.player !== null
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ClippingRectangle {
                visible: cover.status === Image.Ready
                Layout.preferredWidth: 92
                Layout.preferredHeight: 92
                radius: 0
                color: "transparent"

                Image {
                    id: cover

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(184, 184)
                    source: root.player?.trackArtUrl ?? ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle ?? ""
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 16
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    color: Qt.alpha(Theme.text, 0.7)
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                StarWave {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    tint: colour.color
                    listening: Planet.pageEmpty && (root.player?.isPlaying ?? false)
                }
            }
        }

        MediaProgress {
            entering: false
            Layout.fillWidth: true
            tint: colour.color
        }

        MediaControls {
            Layout.alignment: Qt.AlignHCenter
            tint: colour.color
        }
    }
}
