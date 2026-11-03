import QtQuick
import qs.config
import qs.services

// Every card in ETEA: a porthole onto a living sky, framed by a wobbly double ink line
// that breaks around its stars. The seed makes each one a little different, the tint
// and the rise are how a card takes on the colour and the mood of what it's showing.
Item {
    id: root

    property string seed: "etea"
    property real radius: 0
    property real ink: 0.72 // how strong the line is
    property color tint: Theme.windowLit
    property real rise: 0.16 // how high the horizon sits inside the card
    // The sky stops moving when nobody can see it, closed menus and panels included
    property bool alive: false
    property real starSpacing: 130 // one star every so often along the sides, 0 keeps only the corners
    property real starScale: 1

    readonly property alias hovered: hoverWatch.hovered

    readonly property real phase: {
        let total = 7;
        for (let i = 0; i < seed.length; i++)
            total = (total * 31 + seed.charCodeAt(i)) % 9973;
        return total / 97;
    }

    function randomFrom(start) {
        let state = Math.floor(start * 1000) + 11;
        return () => (state = state * 16807 % 2147483647) / 2147483647;
    }

    // The stars sit on the outline: one on each corner, and a few scattered along the sides
    readonly property var stars: {
        return [];
        const w = width, h = height;
        const random = randomFrom(phase);
        const corner = radius * 0.29;
        const s = starScale;
        const points = [
            { x: corner, y: corner, size: 7.5 * s },
            { x: w - corner, y: corner, size: 6 * s },
            { x: w - corner, y: h - corner, size: 7.5 * s },
            { x: corner, y: h - corner, size: 6 * s }
        ];
        const scatter = (length, place) => {
            if (starSpacing <= 0)
                return;
            const count = Math.max(1, Math.round(length / starSpacing));
            for (let i = 0; i < count; i++) {
                const t = (i + 0.5 + (random() - 0.5) * 0.7) / count;
                points.push(Object.assign(place(radius + (length - radius * 2) * t), { size: (2.6 + random() * 2.6) * s }));
            }
        };
        scatter(w, x => ({ x: x, y: 0 }));
        scatter(w, x => ({ x: x, y: h }));
        scatter(h, y => ({ x: 0, y: y }));
        scatter(h, y => ({ x: w, y: y }));
        return points;
    }

    // A hand never holds a straight line, so the outline drifts gently in and out
    function drift(t, shift) {
        return 1.1 * Math.sin(t * 0.027 + shift) + 0.7 * Math.sin(t * 0.071 + shift * 2.1) + 0.3 * Math.sin(t * 0.19 + shift * 3.3);
    }

    // Walks around the rounded rectangle, a few pixels at a time
    function outline(pad, shift) {
        const w = width, h = height, r = radius, points = [];
        const corners = [[w - r, r, -Math.PI / 2], [w - r, h - r, 0], [r, h - r, Math.PI / 2], [r, r, Math.PI]];
        const edges = [[r, 0, w - r, 0], [w, r, w, h - r], [w - r, h, r, h], [0, h - r, 0, r]];
        let walked = 0;
        for (let side = 0; side < 4; side++) {
            const [x1, y1, x2, y2] = edges[side];
            const length = Math.hypot(x2 - x1, y2 - y1);
            const nx = (y2 - y1) / (length || 1), ny = -(x2 - x1) / (length || 1);
            for (let d = 0; d < length; d += 6) {
                const offset = pad + drift(walked + d, shift);
                points.push([x1 + (x2 - x1) * d / length + nx * offset, y1 + (y2 - y1) * d / length + ny * offset]);
            }
            walked += length;
            const [cx, cy, start] = corners[side];
            for (let step = 0; step < 8; step++) {
                const angle = start + Math.PI / 2 * step / 8;
                const reach = r + pad + drift(walked + step * 4, shift);
                points.push([cx + Math.cos(angle) * reach, cy + Math.sin(angle) * reach]);
            }
            walked += r * 1.57;
        }
        return points;
    }


    HoverHandler {
        id: hoverWatch
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.cardDeep
        border.width: 1
        border.color: Qt.alpha(root.tint, root.ink * 0.6)
    }

    ShaderEffect {
        id: sky
        visible: false

        property color deep: Theme.cardDeep
        property color tint: root.tint
        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d pointer: Qt.vector2d(handler.point.position.x, handler.point.position.y)
        property real time: 0
        property real seed: root.phase

        // Hidden, the sky holds still
        Binding on time {
            when: root.alive
            value: Drift.time
            restoreMode: Binding.RestoreNone
        }
        property real hover: root.hovered ? 1 : 0
        property real rise: root.rise
        property real radius: root.radius

        readonly property var handler: hoverWatch

        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../../shaders/porthole.frag.qsb")

        Behavior on hover {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }
        Behavior on rise {
            NumberAnimation { duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
        }
        Behavior on tint {
            ColorAnimation { duration: 600 }
        }
    }

    // Counted once on the shared clock while alive, however often alive flips
    property bool ticking: false

    function tick() {
        if (alive === ticking)
            return;
        ticking = alive;
        alive ? Drift.join() : Drift.leave();
    }

    onAliveChanged: tick()
    Component.onCompleted: tick()
    Component.onDestruction: {
        if (ticking)
            Drift.leave();
    }

    Repeater {
        model: root.stars

        Star {
            required property var modelData

            x: modelData.x - size
            y: modelData.y - size
            size: modelData.size
            lit: true
            animated: false
        }
    }
}
