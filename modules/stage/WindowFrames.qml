import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services

// Every window on the page has its stars ready. Only the focused window shows
// them, so moving the focus is a real crossfade from one frame to the other.
Item {
    id: root

    required property real screenX
    required property real screenY
    property bool active: true

    property bool sliding: false // a layout change, Hyprland is animating the windows
    property bool following: false // something is moving right now, keep up with it
    property bool paging: false // Hyprland is sliding a page in, the stars wait for it
    property string lastShape: ""

    readonly property var pageWindows: Hyprland.toplevels.values.filter(t => t.workspace?.id === Planet.current)

    // Quiet when nothing moves. As soon as something does, we ask every other frame.
    Timer {
        running: root.active && Planet.phase !== Planet.Phase.Spinning
        repeat: true
        interval: root.following ? 32 : 250
        onTriggered: Hyprland.refreshToplevels()
    }

    Timer {
        id: calmDown

        interval: 400
        onTriggered: root.following = false
    }

    Timer {
        id: pageDone

        interval: 420
        onTriggered: root.paging = false
    }

    Timer {
        id: slideDone

        interval: Theme.frameSlide + 80
        onTriggered: root.sliding = false
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "changefloatingmode":
                root.sliding = true;
                slideDone.restart();
                Hyprland.refreshToplevels();
                break;
            case "activewindowv2":
                Hyprland.refreshToplevels();
                break;
            case "workspacev2":
                if (Config.pageTransition === "slide") {
                    root.paging = true;
                    pageDone.restart();
                }
                break;
            }
        }
    }

    Repeater {
        model: root.pageWindows

        Item {
            id: frame

            required property var modelData

            readonly property var info: modelData?.lastIpcObject
            readonly property bool known: info?.size !== undefined
            readonly property bool focused: Hyprland.activeToplevel === modelData
            readonly property string shape: known ? `${info.at} ${info.size}` : ""
            readonly property bool shown: root.active && !root.paging && focused && known && info.fullscreen !== 2 && modelData.address !== Planet.birthing

            x: known ? info.at[0] - root.screenX : 0
            y: known ? info.at[1] - root.screenY : 0
            width: known ? info.size[0] : 0
            height: known ? info.size[1] : 0
            opacity: shown ? 1 : 0
            visible: opacity > 0

            // Shape changed without warning: someone is dragging, so start following
            onShapeChanged: {
                if (focused && !root.sliding) {
                    root.following = true;
                    calmDown.restart();
                }
            }

            // Focus moving within a page crossfades. Landing on a page, the turning stand-in
            // already wore these stars, so they're simply there, no fade-in after the fact.
            Behavior on opacity {
                enabled: Planet.phase === Planet.Phase.Idle

                NumberAnimation {
                    duration: Theme.windowFocusSpeed * 100
                    easing.type: Easing.InOutSine
                }
            }

            // Hyprland eases windows into their new size, so the stars ease along with them
            Behavior on x {
                enabled: root.sliding || root.following
                NumberAnimation { duration: Theme.frameSlide; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: root.sliding || root.following
                NumberAnimation { duration: Theme.frameSlide; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                enabled: root.sliding || root.following
                NumberAnimation { duration: Theme.frameSlide; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                enabled: root.sliding || root.following
                NumberAnimation { duration: Theme.frameSlide; easing.type: Easing.OutCubic }
            }

            FrameStars {
                visible: false // прибрано: зірки на рамках вікон не потрібні
                anchors.fill: parent
                seed: frame.modelData?.address ?? ""
                windowWidth: frame.width
                windowHeight: frame.height
            }
        }
    }
}
