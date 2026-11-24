import QtQuick
import QtMultimedia

// Відео-шпалера теми "Глибокий космос": по колу, без звуку, на весь екран.
// Коли стіл зайнятий вікнами -- пауза, кадр лишається.
Item {
    id: root

    property url source
    property bool playing: true

    onPlayingChanged: playing ? player.play() : player.pause()

    MediaPlayer {
        id: player
        source: root.source
        loops: MediaPlayer.Infinite
        videoOutput: output
        onSourceChanged: play()
        Component.onCompleted: play()
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
