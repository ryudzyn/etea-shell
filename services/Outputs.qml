pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// What may safely be captured right now. A monitor going to sleep can vanish from the system.
// Asking for a screen that's gone crashes Quickshell. Asking for a window that has no monitor
// for a moment crashes Hyprland 0.56 itself (CScreenshareSession::init), and windows only get
// theirs back a little after the monitor returns, so windows wait for things to calm down.
Singleton {
    id: root

    // Qt invents a placeholder screen when the last monitor goes: the compositor doesn't know it
    readonly property var real: Quickshell.screens.filter(screen => Hyprland.monitors.values.some(monitor => monitor.name === screen.name))
    property bool settled: false

    onRealChanged: {
        settled = false;
        calm.restart();
    }

    Timer {
        id: calm

        interval: 3000
        running: true
        onTriggered: root.settled = root.real.length > 0
    }

    function screen(output) {
        return real.includes(output) ? output : null;
    }

    function window(toplevel) {
        return settled && toplevel?.monitor ? toplevel.wayland : null;
    }
}
