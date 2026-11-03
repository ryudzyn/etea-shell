import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar
import qs.services

// What's playing, with the controls that belong to it.
ColumnLayout {
    id: root

    readonly property var player: Music.player

    // The whole card takes on the colour of the cover
    readonly property color cardTint: colour.color
    readonly property real cardRise: 0.07

    spacing: 12
    width: 360

    ContentTint {
        id: colour

        image: root.player?.trackArtUrl ?? ""
        name: root.player?.trackTitle ?? "etea"
    }

    // Several players: pick the one everything follows
    Flow {
        visible: Music.players.length > 1
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: Music.players

            Rectangle {
                required property var modelData
                readonly property bool current: modelData === root.player

                width: name.implicitWidth + 24
                height: 28
                radius: 0
                color: Qt.alpha(Menus.tint, current ? 0.3 : 0.1)
                border.width: 1
                border.color: Qt.alpha(Menus.tint, current ? 0.7 : 0.2)

                Text {
                    id: name

                    anchors.centerIn: parent
                    text: parent.modelData.identity || parent.modelData.desktopEntry || "?"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: Music.chosen = parent.modelData
                }
            }
        }
    }

    Text {
        visible: !root.player
        text: Lang.t("Rien en cours de lecture.")
        color: Qt.alpha(Theme.text, 0.7)
        font.family: Theme.font
        font.pixelSize: 14
    }

    RowLayout {
        visible: root.player !== null
        spacing: 14

        Image {
            visible: status === Image.Ready
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(168, 168)
            source: root.player?.trackArtUrl ?? ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.player?.trackTitle ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 15
            }

            Text {
                Layout.fillWidth: true
                text: root.player?.trackArtist ?? ""
                elide: Text.ElideRight
                color: Qt.alpha(Theme.text, 0.65)
                font.family: Theme.font
                font.pixelSize: 12
            }
        }
    }

    StarWave {
        visible: root.player !== null
        Layout.fillWidth: true
        tint: colour.color
    }

    MediaProgress {
        Layout.fillWidth: true
        tint: colour.color
    }

    MediaControls {
        visible: root.player !== null
        Layout.alignment: Qt.AlignHCenter
        tint: colour.color
    }
}
