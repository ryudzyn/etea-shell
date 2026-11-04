import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services

// A stand-in for one window. Cut out of the page's photo whenever we have one,
// which makes it identical to the real thing. Otherwise a plain window capture.
Item {
    id: root

    required property var toplevel
    required property real screenX
    required property real screenY
    property Item photo: null
    property bool lit: false
    property bool live: false // keep the window playing on top of its photo while the page turns
    property Item backdrop: null
    readonly property bool playing: live && Config.livePages

    // A live capture is the bare window: no blur, no opacity rule, no dimming, Hyprland
    // only adds those on screen. Glass apps get them here: the world blurred behind them,
    // and their opacity, a little lower when they're not the lit one.
    readonly property var glass: Config.glassApps.find(app => app.class === info.class) ?? null
    readonly property real glassOpacity: !glass?.opacity ? 1 : lit ? glass.opacity : Math.max(0.1, glass.opacity - 0.1)
    readonly property bool frosted: glass !== null && backdrop !== null && liveReady
    property bool liveReady: false

    // A window can close mid-spin and take its details with it
    readonly property var info: toplevel?.lastIpcObject?.size ? toplevel.lastIpcObject : ({ at: [0, 0], size: [0, 0] })
    readonly property int edge: Theme.traceWidth

    x: info.at[0] - screenX - edge
    y: info.at[1] - screenY - edge
    width: info.size[0] + edge * 2
    height: info.size[1] + edge * 2

    // The glow spills past the window, so the photo can't carry it along
    WindowGlow {
        visible: root.lit
        anchors.fill: parent
        anchors.margins: -Theme.windowGlowSize
        window: Qt.size(root.info.size[0], root.info.size[1])
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.windowRadius + root.edge
        color: "transparent"

        ShaderEffectSource {
            visible: root.photo !== null && !root.frosted
            anchors.fill: parent
            sourceItem: root.photo
            sourceRect: Qt.rect(root.x, root.y, root.width, root.height)
        }

        // What Hyprland's blur would show through a glass window: the world behind it
        MultiEffect {
            visible: root.frosted
            anchors.fill: parent
            source: ShaderEffectSource {
                sourceItem: root.backdrop
                sourceRect: Qt.rect(root.x, root.y, root.width, root.height)
                live: root.frosted
            }
            blurEnabled: true
            blur: 1
            blurMax: 48
            autoPaddingEnabled: false
        }

        Loader {
            active: root.photo === null
            anchors.fill: parent
            anchors.margins: root.edge

            sourceComponent: ScreencopyView {
                captureSource: Outputs.window(root.toplevel)
                live: root.playing
                onHasContentChanged: {
                    if (hasContent)
                        Planet.noteCaptured();
                }
            }
        }

        // While the page turns, the window keeps playing over its photo: a video runs on,
        // a cursor keeps blinking. The photo underneath still brings the sky, the border
        // and the shadow, and shows until the first live frame arrives.
        Loader {
            active: root.playing && root.photo !== null
            anchors.fill: parent
            anchors.margins: root.edge

            sourceComponent: ScreencopyView {
                captureSource: Outputs.window(root.toplevel)
                live: true
                opacity: hasContent ? root.glassOpacity : 0
                onHasContentChanged: root.liveReady = hasContent
            }
        }

        // Hyprland dims the windows that aren't lit, the live picture has to as well.
        // A photo already has it, so only once the live frames take over, or without one.
        Rectangle {
            visible: root.playing && !root.lit && (root.liveReady || root.photo === null)
            anchors.fill: parent
            color: "black"
            opacity: Theme.windowDim
        }
    }

    // Photos already have their border, only the plain capture needs one drawn
    Rectangle {
        visible: root.photo === null || root.frosted
        anchors.fill: parent
        radius: Theme.windowRadius + root.edge
        color: "transparent"
        border.width: root.edge
        border.color: Qt.alpha(Theme.windowLit, root.lit ? Theme.traceLine : Theme.windowRestBorder)
    }

    // A window keeps its frame on the way round
    FrameStars {
        visible: root.lit
        anchors.fill: parent
        anchors.margins: root.edge
        seed: root.toplevel?.address ?? ""
        windowWidth: root.info.size[0]
        windowHeight: root.info.size[1]
    }
}
