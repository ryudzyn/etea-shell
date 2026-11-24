pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Which bar menu is open, and where it should hang from.
Singleton {
    property string open: ""
    property real anchorX: 0
    property color tint: Theme.windowLit
    property var trayItem: null // the background app whose menu is open

    property bool settingsOpen: false
    property int settingsSection: -1 // куди відкрити налаштування (0 -- "Світ"), -1 -- де був
    property bool sessionOpen: false
    property string lastClosed: ""

    property bool locked: false // the real lock, the session is shut until the password is right
    property bool lockPreview: false // the same scene in an ordinary window, Escape leaves it
    property bool captureOpen: false
    property bool clipboardOpen: false

    // The side panels
    property bool leftOpen: false
    property bool rightOpen: false
    property string panelClosed: ""
    property real panelClosedAt: 0

    function togglePanel(side) {
        if (side === panelClosed && Date.now() - panelClosedAt < 250)
            return;
        const isOpen = side === "left" ? leftOpen : rightOpen;
        if (isOpen) {
            closePanel(side);
            return;
        }
        open = "";
        if (side === "left")
            leftOpen = true;
        else
            rightOpen = true;
    }

    function closePanel(side) {
        panelClosed = side;
        panelClosedAt = Date.now();
        if (side === "left")
            leftOpen = false;
        else
            rightOpen = false;
    }
    property real closedAt: 0

    function toggle(name, x) {
        // Clicking a menu's own button closes it first, and that same click lands here
        // a moment later. Without this check it would pop straight back open.
        if (name === lastClosed && Date.now() - closedAt < 250)
            return;
        anchorX = x;
        if (open === name)
            close();
        else
            open = name;
    }

    function close() {
        lastClosed = open;
        closedAt = Date.now();
        open = "";
    }
}
