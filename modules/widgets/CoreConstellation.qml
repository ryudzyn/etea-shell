import QtQuick
import qs.config
import qs.modules.bar
import qs.services

// The processor as a constellation: one star per core, bigger and brighter the harder it
// works, the busy ones twinkling. Memory is the nebula glowing behind, spreading as it
// fills. Traffic on the network shoots across as comets, more of them the busier it gets.
// Behind windows it all holds still.
Item {
    id: root

    property color ink: Theme.skyInk
    property bool alive: Planet.pageEmpty

    // The readings, held still while nobody can see them
    property var loads: []
    property real memory: 0
    readonly property int count: Math.max(1, loads.length)
    readonly property bool busy: loads.some(load => load > 0.25)

    Binding on loads {
        when: root.alive || root.loads.length === 0
        value: Machine.cores
        restoreMode: Binding.RestoreNone
    }

    Binding on memory {
        when: root.alive || root.memory === 0
        value: Machine.memory
        restoreMode: Binding.RestoreNone
    }

    // Where each core's star sits, as shares of the widget: scattered over a loose grid so
    // they never bunch up, the same for a given number of cores every time
    readonly property var points: {
        const found = [];
        let seed = 7 + count;
        const random = () => (seed = seed * 16807 % 2147483647) / 2147483647;
        const columns = Math.ceil(Math.sqrt(count * 2.4)), rows = Math.ceil(count / columns);
        for (let i = 0; i < count; i++) {
            const column = i % columns, row = Math.floor(i / columns);
            found.push({
                x: 0.08 + 0.84 * (column + 0.5 + (row % 2 ? 0.25 : -0.25) + (random() - 0.5) * 0.7) / columns,
                y: 0.12 + 0.76 * (row + 0.5 + (random() - 0.5) * 0.8) / Math.max(1, rows)
            });
        }
        return found;
    }

    // Joined like a real constellation: every star to its nearest neighbour, without
    // loops (a minimum spanning tree)
    readonly property var lines: {
        const joined = [0], found = [];
        const far = (a, b) => Math.hypot((points[a].x - points[b].x) * width, (points[a].y - points[b].y) * height);
        while (joined.length < points.length) {
            let best = null;
            for (const a of joined) {
                for (let b = 0; b < points.length; b++) {
                    if (!joined.includes(b) && (!best || far(a, b) < best.length))
                        best = { from: a, to: b, length: far(a, b) };
                }
            }
            joined.push(best.to);
            found.push(best);
        }
        return found;
    }

    // The ink as the canvas wants it
    function paint(alpha) {
        return `rgba(${Math.round(ink.r * 255)}, ${Math.round(ink.g * 255)}, ${Math.round(ink.b * 255)}, ${alpha})`;
    }

    // Twinkling rides the shared sky clock, and only while some core is busy
    property bool ticking: false

    function tick() {
        const wanted = alive && busy;
        if (wanted === ticking)
            return;
        ticking = wanted;
        wanted ? Drift.join() : Drift.leave();
    }

    onAliveChanged: tick()
    onBusyChanged: tick()
    Component.onCompleted: tick()
    Component.onDestruction: {
        if (ticking)
            Drift.leave();
    }

    // Memory: drawn once, then only scaled and faded, which costs nothing
    Canvas {
        id: nebula

        anchors.centerIn: parent
        width: root.width
        height: root.height * 1.3
        scale: 0.5 + 0.6 * root.memory
        opacity: 0.25 + 0.55 * root.memory
        renderStrategy: Canvas.Immediate

        Behavior on scale {
            NumberAnimation { duration: 900; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
        }
        Behavior on opacity {
            NumberAnimation { duration: 900 }
        }

        onWidthChanged: requestPaint()
        onPaint: {
            const g = getContext("2d"), w = width, h = height;
            g.reset();
            g.save();
            g.scale(1, h / w);
            const glow = g.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2);
            glow.addColorStop(0, root.paint(0.42));
            glow.addColorStop(0.5, root.paint(0.16));
            glow.addColorStop(1, root.paint(0));
            g.fillStyle = glow;
            g.fillRect(0, 0, w, w);
            g.restore();
        }
    }

    // The thread joining the stars, in the order of the cores
    Canvas {
        id: links

        anchors.fill: parent
        renderStrategy: Canvas.Immediate

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root

            function onLinesChanged() {
                links.requestPaint();
            }
        }

        onPaint: {
            const g = getContext("2d");
            g.reset();
            g.strokeStyle = root.paint(0.3);
            g.lineWidth = 1;
            g.beginPath();
            for (const line of root.lines) {
                g.moveTo(root.points[line.from].x * width, root.points[line.from].y * height);
                g.lineTo(root.points[line.to].x * width, root.points[line.to].y * height);
            }
            g.stroke();
        }
    }

    Repeater {
        model: root.count

        Star {
            id: core

            required property int index
            property real shown: root.loads[index] ?? 0
            readonly property real twinkle: shown > 0.25 ? 0.82 + 0.18 * Math.sin(Drift.time * (2 + 5 * shown) + index * 2.3) : 1

            Behavior on shown {
                NumberAnimation { duration: 900; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
            }

            size: root.height * 0.065
            x: (root.points?.[index]?.x ?? 0.5) * root.width - size
            y: (root.points?.[index]?.y ?? 0.5) * root.height - size
            lit: shown > 0.45
            animated: false
            scale: 0.55 + 0.8 * shown
            opacity: (0.55 + 0.45 * shown) * twinkle
        }
    }

    // A comet now and then, sooner the more data flows
    readonly property real traffic: Machine.download + Machine.upload

    Timer {
        running: root.alive && root.traffic > 20000
        repeat: true
        interval: Math.max(1200, 9000 - 1300 * Math.log10(root.traffic / 1000))
        onTriggered: comet.fly()
    }

    Item {
        id: comet

        property real t: 0
        property real fromY: 0.2

        function fly() {
            if (flight.running)
                return;
            fromY = 0.1 + Math.random() * 0.4;
            flight.restart();
        }

        visible: flight.running
        x: -40 + (root.width + 80) * t
        y: root.height * (fromY + 0.35 * t)
        rotation: 18
        opacity: Math.sin(Math.PI * t)

        NumberAnimation {
            id: flight

            target: comet
            property: "t"
            from: 0
            to: 1
            duration: 900
            easing.type: Easing.InOutSine
        }

        Rectangle {
            x: -width
            y: -height / 2
            width: root.width * 0.18
            height: 2
            radius: 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.alpha(root.ink, 0.8) }
            }
        }

        Star {
            x: -size
            y: -size
            size: 5
            lit: true
            animated: false
        }
    }
}
