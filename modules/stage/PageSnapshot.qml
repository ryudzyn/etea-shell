import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// A photo of the whole screen for one page. It holds what a window capture can't:
// the sky showing through transparent apps, the borders, the shadows.
Item {
    id: root

    required property var output

    readonly property Item frame: loader.item

    // A fresh view takes a fresh photo, and we only trust it once it has content
    function capture() {
        loader.active = false;
        Qt.callLater(() => loader.active = true);
    }

    Loader {
        id: loader

        anchors.fill: parent
        active: false

        sourceComponent: ScreencopyView {
            captureSource: Outputs.screen(root.output)
            live: false
            onHasContentChanged: {
                if (hasContent)
                    Planet.noteCaptured();
            }
        }
    }
}
