pragma Singleton

import QtQuick
import Quickshell

// What a right click offers. An entry is { label, detail, active, run } or, to go one list
// further, { label, items }. { label, input, done } asks for a line of text first.
Singleton {
    id: root

    property var levels: [] // the lists you came through, the last one is on screen
    property point at: Qt.point(0, 0)
    property var screen: null

    readonly property var level: levels.length ? levels[levels.length - 1] : null

    function show(title, items, point, onScreen) {
        at = point;
        screen = onScreen;
        levels = [{ title: title, items: items }];
    }

    function close() {
        levels = [];
    }

    function back() {
        levels = levels.slice(0, -1);
    }

    function pick(entry) {
        if (entry.items)
            levels = levels.concat([{ title: entry.label, items: entry.items }]);
        else if (entry.input !== undefined)
            levels = levels.concat([{ title: entry.label, items: [], input: entry.input, done: entry.done }]);
        else if (entry.run) {
            close();
            entry.run();
        }
    }
}
