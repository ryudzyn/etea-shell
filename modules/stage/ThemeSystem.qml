import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// Сонячна система як вибір столу: кожна планета -- робочий стіл. Стрілки чи коліщатко
// вибирають, Enter або клік летить туди, Esc повертає назад. Схема навмисно суха.
Item {
    id: root

    readonly property real level: Planet.systemLevel
    readonly property real unit: width / 1600
    readonly property real cx: 590 * unit
    readonly property real cy: height * 0.53
    readonly property int chosen: Planet.systemChoice
    readonly property var chosenSpec: Planets.find(Planets.solar[chosen])
    readonly property var chosenWindows: windowsOf(chosen + 1)

    // Велика піввісь в а.о. і середня довгота: L0 + швидкість * днів від J2000, у градусах.
    // Цього досить, щоб розташування відповідало небу з точністю, потрібною для схеми.
    readonly property var orbits: [
        { au: 0.387, l0: 252.25, rate: 4.09233445, px: 5 },
        { au: 0.723, l0: 181.98, rate: 1.60213034, px: 8 },
        { au: 1.0, l0: 100.47, rate: 0.9856091, px: 9 },
        { au: 1.524, l0: 355.43, rate: 0.5240384, px: 7 },
        { au: 5.203, l0: 34.4, rate: 0.0830853, px: 22 },
        { au: 9.537, l0: 49.94, rate: 0.03344414, px: 17 },
        { au: 19.19, l0: 313.23, rate: 0.01172834, px: 12 },
        { au: 30.07, l0: 304.88, rate: 0.00598103, px: 12 }
    ]
    readonly property real days: (Date.now() - Date.UTC(2000, 0, 1, 12)) / 86400000 + clock
    property real clock: 0 // симульовані дні від моменту відкриття, старт -- реальне небо
    property real seconds: 0
    readonly property real speed: 2 // симульованих днів за секунду, Земля робить оберт за 3 хв

    // Перетягування вікна на іншу планету
    property var carried: null
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property int dropTarget: -1
    property var hovered: null

    onVisibleChanged: {
        if (visible)
            clock = 0;
    }

    FrameAnimation {
        running: root.visible
        onTriggered: {
            root.seconds += frameTime;
            if (!root.dragging)
                root.clock += frameTime * root.speed;
        }
    }

    function windowLabel(toplevel) {
        return (toplevel?.lastIpcObject?.class ?? toplevel?.title ?? "?").split(".").pop();
    }

    // Де зараз супутник вікна: номер вікна навколо планети, на своєму колі
    function satelliteX(index, slot, count) {
        const a = seconds * 0.5 + slot * 2 * Math.PI / Math.max(1, count) + index;
        return planetX(index) + Math.cos(a) * (orbits[index].px + 14) * unit;
    }

    function satelliteY(index, slot, count) {
        const a = seconds * 0.5 + slot * 2 * Math.PI / Math.max(1, count) + index;
        return planetY(index) + Math.sin(a) * (orbits[index].px + 14) * unit * 0.7;
    }

    // Що зробити, коли приземлимось: відкрити лончер чи сфокусувати вікно
    property bool launchOnLanding: false
    property var focusOnLanding: null

    Connections {
        target: Planet
        function onPhaseChanged() {
            if (Planet.phase !== Planet.Phase.Idle)
                return;
            if (root.focusOnLanding)
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${root.focusOnLanding.address}" })`);
            if (root.launchOnLanding)
                Apps.open = true;
            root.focusOnLanding = null;
            root.launchOnLanding = false;
        }
    }

    function closeWindow(toplevel) {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${toplevel.address}" })`);
        Hyprland.refreshToplevels();
    }

    function moveWindow(toplevel, page) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${page}, follow = false, window = "address:0x${toplevel.address}" })`);
        Hyprland.refreshToplevels();
    }

    function rx(index) {
        return (70 + Math.log10(orbits[index].au / 0.387) / Math.log10(30.07 / 0.387) * 450) * unit;
    }

    function planetX(index) {
        return cx + Math.cos((orbits[index].l0 + orbits[index].rate * days) * Math.PI / 180) * rx(index);
    }

    function planetY(index) {
        return cy - Math.sin((orbits[index].l0 + orbits[index].rate * days) * Math.PI / 180) * rx(index) * 0.62;
    }

    function windowsOf(page) {
        return Hyprland.toplevels.values.filter(t => t.workspace?.id === page);
    }

    opacity: level
    visible: level > 0.01

    Repeater {
        id: surfaces
        model: Planets.solar
        Image {
            required property var modelData
            visible: false
            mipmap: true
            source: "file://" + Quickshell.shellPath("assets/planets/" + Planets.find(modelData).texture)
        }
    }

    Image {
        id: ringImage
        visible: false
        source: "file://" + Quickshell.shellPath("assets/planets/2k_saturn_ring_alpha.png")
    }

    Image {
        id: cloudImage
        visible: false
        mipmap: true
        source: "file://" + Quickshell.shellPath("assets/planets/2k_earth_clouds.jpg")
    }

    // Камера відлітає назад, коли система відкривається
    Item {
        id: system
        anchors.fill: parent
        transform: Scale {
            origin.x: root.cx
            origin.y: root.cy
            xScale: 1 + 1.4 * (1 - root.level)
            yScale: xScale
        }

        Canvas {
            id: chart
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root
                function onChosenChanged() {
                    chart.requestPaint();
                }
                function onDropTargetChanged() {
                    chart.requestPaint();
                }
            }
            onPaint: {
                const c = getContext("2d");
                c.reset();
                for (let i = 0; i < root.orbits.length; i++) {
                    const r = root.rx(i);
                    c.beginPath();
                    c.ellipse(root.cx - r, root.cy - r * 0.62, r * 2, r * 1.24);
                    c.lineWidth = 1;
                    c.strokeStyle = i === root.dropTarget ? Planets.find(Planets.solar[i]).light
                        : i === root.chosen ? root.chosenSpec.light : "#232b33";
                    c.stroke();
                }
            }
        }

        // Сонце: стримане дихання корони
        Repeater {
            model: [[2.4, 0.05], [1.7, 0.09]]
            Rectangle {
                required property var modelData
                readonly property real base: 34 * root.unit * modelData[0] * (1 + 0.05 * Math.sin(root.seconds * 0.8))
                x: root.cx - base / 2
                y: root.cy - base / 2
                width: base
                height: base
                radius: base / 2
                color: Qt.alpha("#f0c674", modelData[1])
            }
        }
        Rectangle {
            x: root.cx - width / 2
            y: root.cy - height / 2
            width: 34 * root.unit
            height: width
            radius: width / 2
            color: "#f0c674"
        }

        Repeater {
            model: Planets.solar

            Item {
                id: body

                required property var modelData
                required property int index

                readonly property var spec: Planets.find(modelData)
                readonly property real r: root.orbits[index].px * root.unit
                readonly property bool picked: index === root.chosen
                readonly property bool dropping: index === root.dropTarget
                readonly property var wins: root.windowsOf(index + 1)

                x: root.planetX(index)
                y: root.planetY(index)

                ShaderEffect {
                    // Запас під кільця Сатурна
                    width: body.r * 5
                    height: width
                    x: -width / 2
                    y: -height / 2
                    opacity: body.wins.length || body.picked || body.dropping ? 1 : 0.5

                    property vector2d resolution: Qt.vector2d(width, height)
                    property vector2d centre: Qt.vector2d(width / 2, height / 2)
                    property real radius: body.r
                    property real spin: root.seconds * (0.12 + 0.05 * body.index)
                    property real tilt: body.spec.tilt ?? 0
                    property real hasRing: body.spec.ring ? 1 : 0
                    property real hasClouds: body.spec.clouds ? 1 : 0
                    property var cloudMap: cloudImage
                    property real mode: 1
                    property real drift: 0
                    property color rim: body.spec.light
                    property var surface: surfaces.count > body.index ? surfaces.itemAt(body.index) : ringImage
                    property var ringMap: ringImage

                    fragmentShader: Qt.resolvedUrl("../../shaders/planet.frag.qsb")
                }

                Rectangle {
                    visible: body.picked || body.dropping
                    readonly property real side: Math.max(body.r * 2 + 18, 34) + (body.dropping ? 10 : 0)
                    x: -side / 2
                    y: -side / 2
                    width: side
                    height: side
                    color: "transparent"
                    border.width: body.dropping ? 2 : 1
                    border.color: body.spec.light
                }

                Text {
                    x: -width / 2
                    y: -body.r - height - (body.picked || body.dropping ? 16 : 6) * root.unit
                    text: "0" + (body.index + 1)
                    color: body.picked || body.dropping ? body.spec.light : body.wins.length ? "#c9d3dc" : "#7f8c98"
                    font.family: Theme.font
                    font.pixelSize: Math.round(12 * root.unit)
                }
            }
        }

        // Супутники: одне вікно -- один квадрат навколо своєї планети
        Repeater {
            model: Planets.solar

            Repeater {
                id: moons
                required property int index
                readonly property int planet: index
                readonly property var wins: root.windowsOf(index + 1)
                model: wins

                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool lifted: root.dragging && root.carried === modelData
                    readonly property real side: (root.hovered === modelData ? 9 : 6) * root.unit
                    x: root.satelliteX(moons.planet, index, moons.wins.length) - side / 2
                    y: root.satelliteY(moons.planet, index, moons.wins.length) - side / 2
                    width: side
                    height: side
                    visible: !lifted
                    color: root.hovered === modelData ? Planets.find(Planets.solar[moons.planet]).light : "#c9d3dc"
                }
            }
        }
    }

    MouseArea {
        id: hands
        anchors.fill: parent
        enabled: Planet.inSystem
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.dragging ? Qt.ClosedHandCursor : root.hovered ? Qt.OpenHandCursor : Qt.ArrowCursor

        property real pressX: 0
        property real pressY: 0
        property real wheelTravel: 0

        function planetAt(x, y) {
            let best = -1, near = 28 * root.unit;
            for (let i = 0; i < root.orbits.length; i++) {
                const d = Math.hypot(x - root.planetX(i), y - root.planetY(i)) - root.orbits[i].px * root.unit;
                if (d < near) {
                    near = d;
                    best = i;
                }
            }
            return best;
        }

        // Вікно під курсором: на схемі вибраного столу або супутник на орбіті
        function windowAt(x, y) {
            const local = scheme.mapFromItem(root, x, y);
            if (local.x >= 0 && local.y >= 0 && local.x < scheme.width && local.y < scheme.height) {
                for (let i = schemeRects.count - 1; i >= 0; i--) {
                    const w = schemeRects.itemAt(i);
                    if (w && local.x >= w.x && local.y >= w.y && local.x < w.x + w.width && local.y < w.y + w.height)
                        return w.modelData;
                }
                return null;
            }
            for (let p = 0; p < root.orbits.length; p++) {
                const wins = root.windowsOf(p + 1);
                for (let j = 0; j < wins.length; j++) {
                    if (Math.hypot(x - root.satelliteX(p, j, wins.length), y - root.satelliteY(p, j, wins.length)) < 11 * root.unit)
                        return wins[j];
                }
            }
            return null;
        }

        onPressed: mouse => {
            if (mouse.button !== Qt.LeftButton)
                return;
            pressX = mouse.x;
            pressY = mouse.y;
            root.carried = windowAt(mouse.x, mouse.y);
            root.dragging = false;
        }

        onPositionChanged: mouse => {
            if (!pressed) {
                root.hovered = windowAt(mouse.x, mouse.y);
                return;
            }
            if (root.carried && !root.dragging && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 6)
                root.dragging = true;
            if (root.dragging) {
                root.dragX = mouse.x;
                root.dragY = mouse.y;
                root.dropTarget = planetAt(mouse.x, mouse.y);
            }
        }

        onDoubleClicked: mouse => {
            const w = windowAt(mouse.x, mouse.y);
            if (!w || mouse.button !== Qt.LeftButton)
                return;
            root.focusOnLanding = w;
            Planet.landPage(w.workspace?.id ?? Planet.current);
        }

        onReleased: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                const w = windowAt(mouse.x, mouse.y);
                if (w) {
                    root.closeWindow(w);
                    root.hovered = null;
                }
                return;
            }
            if (mouse.button === Qt.RightButton) {
                const i = planetAt(mouse.x, mouse.y);
                if (i >= 0) {
                    root.launchOnLanding = true;
                    Planet.landPage(i + 1);
                }
                return;
            }
            if (root.dragging) {
                const from = root.carried.workspace?.id;
                if (root.dropTarget >= 0 && root.dropTarget + 1 !== from)
                    root.moveWindow(root.carried, root.dropTarget + 1);
            } else if (!root.carried) {
                const i = planetAt(mouse.x, mouse.y);
                if (i === root.chosen)
                    Planet.landPage(i + 1);
                else if (i >= 0)
                    Planet.slideSystemTo(i);
            } else {
                Planet.slideSystemTo((root.carried.workspace?.id ?? 1) - 1);
            }
            root.dragging = false;
            root.carried = null;
            root.dropTarget = -1;
        }

        onWheel: wheel => {
            wheelTravel += wheel.angleDelta.y || wheel.angleDelta.x;
            if (Math.abs(wheelTravel) >= 120) {
                Planet.chooseStep(wheelTravel > 0 ? -1 : 1);
                wheelTravel = 0;
            }
        }
    }

    // Панель вибраного столу
    Column {
        x: root.width - width - 48 * root.unit + (1 - root.level) * 120 * root.unit
        y: 72 * root.unit
        width: 372 * root.unit
        spacing: 12

        Item {
            width: parent.width
            height: 28 * root.unit

            Text {
                text: "0" + (root.chosen + 1) + " · " + root.chosenSpec.name.toUpperCase()
                color: root.chosenSpec.light
                font.family: Theme.font
                font.pixelSize: Math.round(15 * root.unit)
                font.weight: Font.Medium
            }
            Text {
                anchors.right: parent.right
                text: root.chosenWindows.length + " вікон"
                color: "#8b98a4"
                font.family: Theme.font
                font.pixelSize: Math.round(13 * root.unit)
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.chosenSpec.light
            }
        }

        // Схема вікон столу в масштабі екрана
        Rectangle {
            id: scheme
            width: parent.width
            height: width * root.height / root.width
            color: "#05070a"
            border.width: 1
            border.color: "#2c3540"
            clip: true

            Repeater {
                id: schemeRects
                model: root.chosenWindows

                Rectangle {
                    required property var modelData
                    readonly property var info: modelData.lastIpcObject ?? {}
                    readonly property real k: scheme.width / root.width

                    x: (info.at?.[0] ?? 0) * k
                    y: (info.at?.[1] ?? 0) * k
                    width: (info.size?.[0] ?? 0) * k
                    height: (info.size?.[1] ?? 0) * k
                    color: "#10151b"
                    border.width: 1
                    border.color: "#4a5763"

                    ScreencopyView {
                        anchors.fill: parent
                        anchors.margins: 1
                        captureSource: parent.modelData.wayland
                        live: root.level > 0.9
                    }

                    Text {
                        x: 6
                        y: 4
                        width: parent.width - 12
                        elide: Text.ElideRight
                        text: (parent.info.class ?? parent.modelData.title).split(".").pop()
                        color: "#8b98a4"
                        font.family: Theme.font
                        font.pixelSize: Math.round(11 * root.unit)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.chosenWindows.length === 0
                text: "ПОРОЖНЬО"
                color: "#7f8c98"
                font.family: Theme.font
                font.pixelSize: Math.round(12 * root.unit)
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.dragging ? "Кинь вікно на планету" : root.chosenSpec.line + " · Enter летіти · Esc назад\nМиша: тягни вікно · 2 кліки до нього · середня закрити · права запуск тут"
            color: "#8b98a4"
            font.family: Theme.font
            font.pixelSize: Math.round(12 * root.unit)
        }

        Item {
            width: 1
            height: 8
        }

        Text {
            text: "СТОЛИ"
            color: "#8b98a4"
            font.family: Theme.font
            font.pixelSize: Math.round(11 * root.unit)
            font.letterSpacing: 1.5
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#2c3540"
        }

        Repeater {
            model: Planets.solar

            Row {
                id: row
                required property var modelData
                required property int index
                readonly property var wins: root.windowsOf(index + 1)
                readonly property color tint: index === root.chosen ? Planets.find(modelData).light : wins.length ? "#c9d3dc" : "#7f8c98"
                spacing: 0

                Text {
                    width: 36 * root.unit
                    text: "0" + (row.index + 1)
                    color: row.tint
                    font.family: Theme.font
                    font.pixelSize: Math.round(13 * root.unit)
                }
                Text {
                    width: 112 * root.unit
                    text: Planets.find(row.modelData).name
                    color: row.tint
                    font.family: Theme.font
                    font.pixelSize: Math.round(13 * root.unit)
                }
                Text {
                    width: 224 * root.unit
                    elide: Text.ElideRight
                    text: row.wins.map(t => (t.lastIpcObject?.class ?? "?").split(".").pop()).join(" · ") || "—"
                    color: row.tint
                    font.family: Theme.font
                    font.pixelSize: Math.round(13 * root.unit)
                }
            }
        }
    }

    Text {
        x: 48 * root.unit
        y: 72 * root.unit
        text: "СИМУЛЯЦІЯ · " + new Date(Date.now() + root.clock * 86400000).toISOString().slice(0, 10) + " · ×" + Math.round(root.speed * 86400).toLocaleString(Qt.locale("C"), "f", 0)
        color: "#8b98a4"
        font.family: Theme.font
        font.pixelSize: Math.round(12 * root.unit)
    }

    // Те, що несеш, а без перетягування -- підпис вікна під курсором
    Rectangle {
        visible: root.dragging || root.hovered !== null
        x: (root.dragging ? root.dragX : hands.mouseX) + 14
        y: (root.dragging ? root.dragY : hands.mouseY) + 14
        width: tag.implicitWidth + 16
        height: tag.implicitHeight + 8
        color: "#0b0e12"
        border.width: 1
        border.color: root.dropTarget >= 0 ? Planets.find(Planets.solar[root.dropTarget]).light : "#4a5763"

        Text {
            id: tag
            anchors.centerIn: parent
            text: root.windowLabel(root.dragging ? root.carried : root.hovered) + (root.dropTarget >= 0 ? " → 0" + (root.dropTarget + 1) : "")
            color: "#c9d3dc"
            font.family: Theme.font
            font.pixelSize: Math.round(12 * root.unit)
        }
    }
}
