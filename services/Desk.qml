pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The widgets on the desktop: which ones are out, where they stand, how big they are.
// Everything is saved in Config.widgets, one entry per kind of widget.
Singleton {
    id: root

    // Every kind of widget there is
    readonly property var catalog: [
        { type: "clock", label: Lang.t("Horloge"), icon: "timer" },
        { type: "system", label: Lang.t("Instruments du système"), icon: "cpu" },
        { type: "media", label: Lang.t("Lecteur de musique"), icon: "music" },
        { type: "weather", label: Lang.t("Météo"), icon: "cloud-sun" },
        { type: "calendar", label: Lang.t("Calendrier et lune"), icon: "calendar" },
        { type: "tasks", label: Lang.t("Tâches"), icon: "checklist" },
        { type: "photo", label: Lang.t("Cadre photo"), icon: "image" },
        { type: "lyrics", label: Lang.t("Paroles"), icon: "lyrics" },
        { type: "object", label: "Об'єкт", icon: "public" },
        { type: "sky", label: "Небо", icon: "public" }
    ]

    // Where each one stands until you move it, and which of its points stands there:
    // 0 is its left or top edge, 1 the other one. They keep to the sides, the middle
    // belongs to the clock.
    readonly property var places: ({
        clock: { x: 0.03, y: 0.08, ax: 0, ay: 0 },
        calendar: { x: 0.03, y: 0.375, ax: 0, ay: 0 },
        system: { x: 0.03, y: 0.94, ax: 0, ay: 1 },
        lyrics: { x: 0.5, y: 0.09, ax: 0.5, ay: 0.5 },
        media: { x: 0.97, y: 0.08, ax: 1, ay: 0 },
        weather: { x: 0.97, y: 0.27, ax: 1, ay: 0 },
        tasks: { x: 0.97, y: 0.44, ax: 1, ay: 0 },
        object: { x: 0.97, y: 0.94, ax: 1, ay: 1 },
        sky: { x: 0.97, y: 0.55, ax: 1, ay: 0 },
        photo: { x: 0.5, y: 0.5, ax: 0.5, ay: 0.5 }
    })

    // Only changes when a widget comes or goes, so moving one doesn't rebuild the others
    property var shown: []

    property string hovered: "" // the widget under the pointer, for Super + wheel
    property bool carrying: false // a widget is being dragged right now
    // When Hyprland last said Super + left button went down over a widget. A moment, not a
    // state: let go of Super before the button and Hyprland never says it's over.
    property real grabbedAt: 0
    property real lastGesture: 0 // when a Super gesture last landed on a widget

    // Hyprland's Super + drag moves windows, and swallows the click even over the empty
    // desktop. So while the pointer rests on a widget, that bind steps aside for one of
    // ours that lets the click through and tells us Super is down: the desktop never has
    // the keyboard, so the click itself arrives without it. It comes back as soon as the
    // pointer leaves, and only if there was such a bind to begin with. Hyprland remembers
    // it was swapped, so a reload or a crash of the shell can't leave it missing.
    property bool windowDrag: false
    property bool lifted: false
    readonly property bool liftWanted: windowDrag && (hovered !== "" || carrying)

    readonly property string putBack: 'if ETEA_LIFTED then hl.unbind("SUPER + mouse:272") hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" }) end ETEA_LIFTED = false'

    onLiftWantedChanged: lift()

    function lift() {
        if (swap.running || lifted === liftWanted)
            return;
        lifted = liftWanted;
        swap.command = ["hyprctl", "eval", lifted ? 'hl.unbind("SUPER + mouse:272") hl.bind("SUPER + mouse:272", hl.dsp.global("etea:deskGrab"), { non_consuming = true }) ETEA_LIFTED = true' : root.putBack];
        swap.running = true;
    }

    // The card of options, opened with a right click
    property string menuFor: "" // a widget, or nothing
    property point menuAt: Qt.point(0, 0)
    property var menuScreen: null

    function label(type) {
        return catalog.find(entry => entry.type === type)?.label ?? type;
    }

    function entry(type) {
        return Config.widgets.find(widget => widget.type === type) ?? { type: type, shown: false };
    }

    // Where it stands now: its own spot once moved, the style's default until then
    function place(type) {
        const saved = entry(type), base = places[type] ?? { x: 0.5, y: 0.5, ax: 0.5, ay: 0.5 };
        if (saved.placed)
            return { x: saved.x, y: saved.y, ax: base.ax, ay: base.ay };
        // The celestial style always read x and y from the file
        if (Config.widgetStyle !== "sky" && saved.x !== undefined)
            return { x: saved.x, y: saved.y, ax: base.ax, ay: base.ay };
        return base;
    }

    function size(type) {
        return entry(type).size ?? 1;
    }

    function update(type, changes) {
        const list = Config.widgets.slice();
        const at = list.findIndex(widget => widget.type === type);
        if (at < 0)
            list.push(Object.assign({ type: type }, changes));
        else
            list[at] = Object.assign({}, list[at], changes);
        Config.widgets = list;
    }

    function add(type) {
        update(type, { shown: true });
    }

    function remove(type) {
        update(type, { shown: false });
    }

    function move(type, x, y) {
        update(type, { x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y)), placed: true });
    }

    function grow(type, steps) {
        lastGesture = Date.now();
        update(type, { size: Math.round(Math.max(0.5, Math.min(1.6, size(type) + steps * 0.05)) * 100) / 100 });
    }

    // Only the click Hyprland just announced counts, the next plain click must stay plain
    function takeGrab() {
        const fresh = Date.now() - grabbedAt < 250;
        grabbedAt = 0;
        return fresh;
    }

    function openMenu(type, at, screen) {
        menuAt = at;
        menuScreen = screen;
        menuFor = type;
    }

    function refresh() {
        const next = Config.widgets.filter(widget => widget.shown !== false && catalog.some(entry => entry.type === widget.type)).map(widget => widget.type);
        if (next.join() !== shown.join())
            shown = next;
    }

    Connections {
        target: Config

        function onWidgetsChanged() {
            root.refresh();
        }
    }

    GlobalShortcut {
        appid: "etea"
        name: "deskGrab"
        onPressed: root.grabbedAt = Date.now()
    }

    // The pointer can come and go faster than hyprctl answers, so catch up once it's done
    Process {
        id: swap

        onExited: root.lift()
    }

    // Anything a previous run left lifted comes back before we look
    Process {
        running: true
        command: ["hyprctl", "eval", root.putBack]
        onExited: binds.running = true
    }

    // Is there a Super + left button bind to step aside?
    Process {
        id: binds

        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windowDrag = JSON.parse(text).some(bind => bind.modmask === 64 && bind.key === "mouse:272");
                } catch (error) {
                    root.windowDrag = false;
                }
            }
        }
    }

    // A reload brings Hyprland's binds back as they were written
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.lifted = false;
                binds.running = true;
                root.lift();
            }
        }
    }

    // qs ipc call desk state, or add, remove and grow from a script
    IpcHandler {
        target: "desk"

        function state(): string {
            return root.shown.map(type => {
                const at = root.place(type);
                return `${type} at ${at.x.toFixed(3)},${at.y.toFixed(3)} size ${root.size(type)}`;
            }).join("\n");
        }

        function add(type: string): void {
            root.add(type);
        }

        function remove(type: string): void {
            root.remove(type);
        }

        function grow(type: string, steps: int): void {
            root.grow(type, steps);
        }
    }

    Component.onCompleted: refresh()
}
