import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.services

// Closing a window: we snap a photo, really close it, then play out the ending on
// that photo. It folds into a star, and the star flies home to its page in the bar.
Item {
    id: root

    required property var output
    required property real screenX
    required property real screenY

    property var closing: null
    property string address: ""
    property int page: 0
    property rect area: Qt.rect(0, 0, 0, 0)
    property bool playing: false

    function closeNow(target) {
        const address = target.startsWith("0x") ? target : `0x${target}`;
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${address}" })`);
    }

    function close(window) {
        const info = window?.lastIpcObject;
        if (!window)
            return;
        if (playing || !info?.size || info.fullscreen === 2) {
            closeNow(window.address);
            return;
        }
        closing = window;
        address = window.address;
        page = window.workspace?.id ?? Planet.current;
        area = Qt.rect(info.at[0] - screenX - Theme.traceWidth, info.at[1] - screenY - Theme.traceWidth, info.size[0] + Theme.traceWidth * 2, info.size[1] + Theme.traceWidth * 2);
        playing = true;
        photo.active = true;
        giveUp.restart();
    }

    function begin() {
        giveUp.stop();
        closeNow(address);
        mask.reach = mask.fullReach;
        star.x = area.x + area.width / 2 - star.width / 2;
        star.y = area.y + area.height / 2 - star.height / 2;
        scene.visible = true;
        ending.restart();
    }

    function finish() {
        scene.visible = false;
        photo.active = false;
        playing = false;
        closing = null;
    }

    // A window should always close, even if the photo never shows up
    Timer {
        id: giveUp

        interval: 120
        onTriggered: {
            root.closeNow(root.address);
            root.finish();
        }
    }

    Item {
        anchors.fill: parent
        opacity: 0

        Loader {
            id: photo

            anchors.fill: parent
            active: false

            sourceComponent: ScreencopyView {
                captureSource: Outputs.screen(root.output)
                live: false
                onHasContentChanged: {
                    if (hasContent)
                        root.begin();
                }
            }
        }
    }

    Item {
        id: scene

        anchors.fill: parent
        visible: false

        ShaderEffectSource {
            id: cutout

            sourceItem: photo.item
            sourceRect: root.area
            hideSource: false
            visible: false
            width: root.area.width
            height: root.area.height
        }

        StarMask {
            id: mask

            x: root.area.x
            y: root.area.y
            width: root.area.width
            height: root.area.height
            source: cutout
        }

        Star {
            id: star

            size: Theme.closeStarSize
            lit: true
            appear: scene.visible
        }
    }

    SequentialAnimation {
        id: ending

        ParallelAnimation {
            NumberAnimation {
                target: mask
                property: "reach"
                to: 0
                duration: Theme.closeFold
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: mask
                property: "shine"
                from: 0
                to: 0.9
                duration: Theme.closeFold
                easing.type: Easing.OutCubic
            }
        }

        // Off it goes, in a curve, towards the page it belonged to
        ParallelAnimation {
            NumberAnimation {
                target: star
                property: "x"
                to: Planet.pagePoint(root.page).x - star.width / 2
                duration: Theme.closeFlight
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: star
                property: "y"
                to: Planet.pagePoint(root.page).y - star.height / 2
                duration: Theme.closeFlight
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: star
                property: "size"
                to: 5
                duration: Theme.closeFlight
                easing.type: Easing.InQuad
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.closeFlight * 0.7 }
                NumberAnimation {
                    target: star
                    property: "opacity"
                    to: 0
                    duration: Theme.closeFlight * 0.3
                }
            }
        }

        ScriptAction {
            script: {
                star.opacity = 1;
                star.size = Theme.closeStarSize;
                mask.shine = 0;
                root.finish();
            }
        }
    }

    GlobalShortcut {
        appid: "etea"
        name: "closeWindow"
        onPressed: root.close(Hyprland.activeToplevel)
    }

    // Lets us close one exact window from outside, which keeps testing safe
    IpcHandler {
        target: "window"

        function close(address: string): void {
            root.close(Hyprland.toplevels.values.find(t => `0x${t.address}` === address || t.address === address));
        }
    }
}
