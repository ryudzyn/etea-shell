import QtQuick
import qs.config
import qs.services

// The song's words written on the sky as it plays, karaoke style: the line being sung
// takes your world's light while a star rides the thread under it, the one before
// fades above, the next waits below.
Column {
    id: root

    property real sky: 1080
    property var options: ({})
    property real enter: 0 // 1 the moment a new line comes up, back to 0 as it settles

    readonly property bool singing: Lyrics.lookup === "found"
    readonly property string waiting: {
        if (!Music.player)
            return Lang.t("Les paroles apparaîtront ici.");
        switch (Lyrics.lookup) {
        case "loading":
            return Lang.t("On cherche les paroles…");
        case "none":
            return Lang.t("Pas de paroles synchronisées pour ce titre.");
        case "offline":
            return Lang.t("Paroles hors de portée pour l'instant.");
        }
        return "";
    }

    width: sky * 0.62
    spacing: sky * 0.006

    Connections {
        target: Lyrics

        function onIndexChanged() {
            rise.restart();
        }
    }

    NumberAnimation {
        id: rise

        target: root
        property: "enter"
        from: 1
        to: 0
        duration: 420
        easing.type: Easing.OutCubic
    }

    Text {
        visible: root.singing
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Lyrics.line(-1)
        elide: Text.ElideRight
        color: Qt.alpha(Theme.skyInk, 0.35)
        font.family: Theme.font
        font.pixelSize: root.sky * 0.0125
    }

    KaraokeLine {
        visible: root.singing
        width: parent.width
        // Between two lines, or before the first, three stars hold the place
        text: Lyrics.line(0)
        resting: Lyrics.index < 0 || Lyrics.line(0) === ""
        progress: Lyrics.progress
        ink: Theme.skyInk
        size: root.sky * 0.024
        opacity: 1 - root.enter * 0.7

        transform: Translate {
            y: root.enter * root.sky * 0.02
        }
    }

    Text {
        visible: root.singing
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: Lyrics.line(1)
        elide: Text.ElideRight
        color: Qt.alpha(Theme.skyInk, 0.5)
        font.family: Theme.font
        font.pixelSize: root.sky * 0.0125
    }

    Text {
        visible: !root.singing
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.waiting
        color: Qt.alpha(Theme.skyInk, 0.6)
        font.family: Theme.font
        font.pixelSize: root.sky * 0.0125
    }
}
