import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.services

// Opening a window is a star being born. A photo taken at that moment would already be
// too late, apps redraw almost instantly, so we always keep a recent one at hand. When
// Hyprland warns that a window is coming, that photo freezes the screen on the spot, and
// behind it windows are free to move and resize however they like. A star then opens from
// the new window and wipes across the screen, revealing everything in its final place.
Item {
    id: root

    required property var output
    property bool active: true

    property var window: null
    property string waitingFor: ""
    property int tries: 0
    property bool frozen: false
    property bool playing: false

    // The warning and the window can reach us in either order
    function freeze() {
        if (!active || playing || !recent.hasContent)
            return;
        frozen = true;
        giveUp.restart();
        if (window)
            start();
    }

    function reset() {
        birth.stop();
        giveUp.stop();
        searching.stop();
        frozen = false;
        playing = false;
        window = null;
        waitingFor = "";
        mask.reach = 0;
        mask.shine = 0;
        star.opacity = 1;
        Planet.birthing = "";
    }

    function look() {
        const found = Hyprland.toplevels.values.find(t => t.address === waitingFor || t.address === `0x${waitingFor}`);
        const info = found?.lastIpcObject;
        if (!info?.size || info.size[0] <= 0) {
            if (++tries < 12) {
                Hyprland.refreshToplevels();
                searching.restart();
            }
            return;
        }
        // Opening on another page or in fullscreen: nothing to show here
        if (found.workspace?.id !== Planet.current || info.fullscreen === 2) {
            reset();
            return;
        }
        window = found;
        if (frozen)
            start();
    }

    function start() {
        if (playing)
            return;
        const info = window.lastIpcObject;
        giveUp.stop();
        Planet.birthing = window.address;
        mask.center = Qt.point(info.at[0] + info.size[0] / 2 - root.output.x, info.at[1] + info.size[1] / 2 - root.output.y);
        mask.reach = 0;
        mask.shine = 0.9;
        playing = true;
        birth.restart();
    }

    // A new world: hold the screen still on the last photo, change the world behind it,
    // then open the same star from the middle of the screen
    function changeWorld(id) {
        if (!active || playing || !recent.hasContent) {
            Config.theme = id;
            return;
        }
        frozen = true;
        playing = true;
        mask.center = Qt.point(width / 2, height / 2);
        mask.reach = 0;
        mask.shine = 0.9;
        Config.theme = id;
        worldSettle.restart();
    }

    // Give the new colours a moment to reach every window before the star opens
    Timer {
        id: worldSettle

        interval: 140
        onTriggered: birth.restart()
    }

    Connections {
        target: Planet

        function onWorldWanted(id) {
            root.changeWorld(id);
        }
    }

    // The warning came but no window followed: thaw the screen
    Timer {
        id: giveUp

        interval: 900
        onTriggered: root.reset()
    }

    Timer {
        id: searching

        interval: 25
        onTriggered: root.look()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "openwindow" || !root.active || root.playing)
                return;
            root.waitingFor = event.data.split(",")[0];
            root.tries = 0;
            Hyprland.refreshToplevels();
            searching.restart();
        }
    }

    GlobalShortcut {
        appid: "etea"
        name: "windowOpening"
        onPressed: root.freeze()
    }

    Item {
        anchors.fill: parent
        opacity: 0

        ScreencopyView {
            id: recent

            anchors.fill: parent
            captureSource: Outputs.screen(root.output)
            live: false
        }
    }

    // Hands off the keyboard and mouse, nothing is about to open: the photos rest.
    // The first touch takes a new one straight away.
    IdleMonitor {
        id: idle

        timeout: 8
        respectInhibitors: false
        onIsIdleChanged: {
            if (!isIdle && root.active && !root.frozen)
                recent.captureFrame();
        }
    }

    // Keeps the photo fresh, but never while something is playing over the screen
    Timer {
        running: root.active && !root.frozen && !idle.isIdle && Planet.phase === Planet.Phase.Idle
        repeat: true
        interval: Theme.openPhotoEvery
        onTriggered: recent.captureFrame()
    }

    Item {
        anchors.fill: parent
        visible: root.frozen

        ShaderEffectSource {
            id: picture

            sourceItem: recent
            visible: false
            width: root.width
            height: root.height
        }

        StarMask {
            id: mask

            anchors.fill: parent
            source: picture
            flipped: 1
        }

        Star {
            id: star

            visible: root.playing
            x: mask.center.x - width / 2
            y: mask.center.y - height / 2
            size: Theme.closeStarSize
            lit: true
            appear: root.playing
        }
    }

    SequentialAnimation {
        id: birth

        // The star flares up first, then opens across the screen
        PauseAnimation { duration: Theme.openSpark }

        ParallelAnimation {
            NumberAnimation {
                target: mask
                property: "reach"
                to: mask.fullReach
                duration: Theme.openReveal
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: mask
                property: "shine"
                to: 0
                duration: Theme.openReveal
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: star
                property: "opacity"
                to: 0
                duration: Theme.openReveal * 0.4
            }
        }

        ScriptAction {
            script: root.reset()
        }
    }
}
