import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.services

// "Куди летимо?" Без введення: планета столу й програми на її кільцях, найближче -- те, що
// запускаєш частіше. Введення шукає програми, вікна й обчислення, ">" запускає команду.
// Tab -- каталог усіх програм списком. Програму з кільця можна перенести на стіл у барі.
Scope {
    id: root

    GlobalShortcut {
        appid: "etea"
        name: "launcher"

        // Hyprland only reports a lone Super key once it's let go, as a release. It also
        // skips that release if another key came along, so Super + 1 leaves this alone.
        // Letting go of Super after moving or resizing a widget isn't a call for it either.
        onReleased: {
            if (Date.now() - Desk.lastGesture > 600)
                Apps.open = !Apps.open;
        }
    }

    // Straight to the emoji: the launcher opens with ":" already typed
    GlobalShortcut {
        appid: "etea"
        name: "emoji"
        onPressed: {
            Apps.startWith = ":";
            Apps.open = true;
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Apps.open = !Apps.open;
        }

        // Відкрити одразу з цим текстом або каталогом: для скриптів і перевірок
        function search(text: string): void {
            Apps.startWith = text;
            Apps.open = true;
        }

        function browse(): void {
            Apps.open = true;
            panel.catalog = true;
            panel.refresh();
        }
    }

    PanelWindow {
        id: panel

        property real shown: Apps.open ? 1 : 0
        property var found: [] // що зараз показано: кільця, результати пошуку або каталог
        property int chosen: 0
        property point pointer: Qt.point(width / 2, height / 2)
        property bool catalog: false // Tab: усі програми списком
        property real drift: 0 // кільця повільно обертаються, поки миша не над програмою
        property int hovering: 0

        readonly property bool typing: input.text.trim() !== ""
        readonly property bool orbits: !typing && !catalog
        readonly property real unit: width / 1600
        readonly property real cx: width * 0.55
        readonly property real cy: height * 0.52

        // Кільця: ближче до планети те, що запускаєш частіше. rx у пікселях на 1600 ширини.
        readonly property var rings: [
            { label: "ЧАСТО", rx: 170, count: 6, size: 1 },
            { label: "ІНКОЛИ", rx: 305, count: 10, size: 0.82 },
            { label: "РІДКО", rx: 440, count: 14, size: 0.68 }
        ]

        function placeOf(entry) {
            const ring = rings[entry.ring];
            // Під час зміни режиму кільця на мить бачать елементи списку
            if (!ring)
                return Qt.point(cx, cy);
            const angle = entry.phase + drift * (entry.ring + 1);
            return Qt.point(cx + Math.cos(angle) * ring.rx * unit, cy + Math.sin(angle) * ring.rx * unit * 0.62);
        }

        function groupOf(entry) {
            switch (entry.kind) {
            case "app":
                return Apps.families[Apps.familyOf(entry.app)].name.toUpperCase();
            case "window":
                return "ВІКНО";
            case "sum":
                return "ОБЧИСЛЕННЯ";
            case "web":
                return "ВЕБ";
            case "command":
                return "КОМАНДА";
            case "emoji":
                return "ЕМОДЗІ";
            }
            return "";
        }

        function refresh() {
            // Читаємо поле прямо зараз: прив'язка могла ще не встигнути за текстом
            const text = input.text.trim();
            if (text !== "") {
                found = Apps.search(input.text);
            } else if (catalog) {
                found = Apps.everything.slice().sort((a, b) => a.name.localeCompare(b.name)).map(Apps.appEntry);
            } else {
                const apps = Apps.everything.slice().sort(Apps.byUse);
                const placed = [];
                let from = 0;
                rings.forEach((ring, index) => {
                    apps.slice(from, from + ring.count).forEach((app, slot) => {
                        placed.push(Object.assign(Apps.appEntry(app), { ring: index, phase: (slot + 0.5 + index * 0.3) / ring.count * Math.PI * 2 - Math.PI / 2 }));
                    });
                    from += ring.count;
                });
                found = placed;
            }
            chosen = 0;
        }

        function move(step) {
            if (found.length)
                chosen = (chosen + step + found.length) % found.length;
        }

        function launch() {
            if (found[chosen])
                Apps.run(found[chosen]);
        }

        // Стіл у барі під курсором, щоб скинути на нього програму
        function pageUnder(x, y) {
            const area = Planet.pagesArea;
            if (area.width === 0 || y < area.y - 20 || y > area.y + area.height + 20)
                return 0;
            const place = Math.floor((x - area.x) / (Theme.pageWidth + Theme.pageGap));
            return place >= 0 && place < Config.pages ? Planet.groupStart + place : 0;
        }

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: shown > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:launcher"
        WlrLayershell.keyboardFocus: Apps.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Behavior on shown {
            NumberAnimation { duration: Theme.launcherFade; easing.type: Easing.OutCubic }
        }

        Connections {
            target: Apps

            function onOpenChanged() {
                if (!Apps.open)
                    return;
                panel.catalog = false;
                panel.hovering = 0;
                input.text = Apps.startWith;
                Apps.startWith = "";
                panel.refresh();
                input.forceActiveFocus();
            }
        }

        FrameAnimation {
            running: panel.visible && panel.orbits && panel.hovering === 0
            onTriggered: panel.drift += frameTime * 0.012
        }

        // Значки всіх програм тримаємо в пам'яті й вантажимо потроху після старту
        Item {
            visible: false

            ListModel {
                id: warm
            }

            Timer {
                running: warm.count < Apps.everything.length
                repeat: true
                interval: 60
                onTriggered: {
                    for (const app of Apps.everything.slice(warm.count, warm.count + 12))
                        warm.append({ icon: Quickshell.iconPath(app.icon, true) });
                }
            }

            Repeater {
                model: warm

                Image {
                    required property string icon

                    sourceSize: Qt.size(96, 96)
                    source: icon
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.launcherShade
            opacity: panel.shown * Theme.launcherDim

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPressed: Apps.open = false
                onPositionChanged: mouse => panel.pointer = Qt.point(mouse.x, mouse.y)
            }
        }

        Item {
            id: sky

            anchors.fill: parent
            opacity: panel.shown

            // Планета поточного столу в центрі кілець
            Image {
                id: surfaceImage
                visible: false
                mipmap: true
                source: Theme.planet.texture ? "file://" + Quickshell.shellPath("assets/planets/" + Theme.planet.texture) : ""
            }
            Image {
                id: cloudImage
                visible: false
                mipmap: true
                source: "file://" + Quickshell.shellPath("assets/planets/2k_earth_clouds.jpg")
            }
            Image {
                id: ringImage
                visible: false
                source: "file://" + Quickshell.shellPath("assets/planets/2k_saturn_ring_alpha.png")
            }
            ShaderEffect {
                readonly property real body: Math.min(panel.height * 0.11, Math.max(60, panel.height * (Theme.planet.size ?? 0.2) * 0.4))

                visible: panel.orbits && Theme.planet.texture !== undefined
                width: body * 5
                height: width
                x: panel.cx - width / 2
                y: panel.cy - height / 2
                opacity: panel.shown

                property vector2d resolution: Qt.vector2d(width, height)
                property vector2d centre: Qt.vector2d(width / 2, height / 2)
                property real radius: body
                property real spin: panel.drift * 4
                property real tilt: Theme.planet.tilt ?? 0
                property real hasRing: Theme.planet.ring ? 1 : 0
                property real hasClouds: Theme.planet.clouds ? 1 : 0
                property real mode: 1
                property real drift: 0
                property color rim: Theme.planet.light
                property var surface: surfaceImage
                property var cloudMap: cloudImage
                property var ringMap: ringImage

                fragmentShader: Qt.resolvedUrl("../../shaders/planet.frag.qsb")
            }

            // Кільця й підписи
            Canvas {
                id: orbitLines

                anchors.fill: parent
                visible: panel.orbits
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const g = getContext("2d");
                    g.reset();
                    g.strokeStyle = "#39434e";
                    g.lineWidth = 1;
                    for (const ring of panel.rings) {
                        const rx = ring.rx * panel.unit;
                        g.beginPath();
                        g.ellipse(panel.cx - rx, panel.cy - rx * 0.62, rx * 2, rx * 1.24);
                        g.stroke();
                    }
                }
            }

            Repeater {
                model: panel.orbits ? panel.rings : []

                Text {
                    required property var modelData
                    z: -1
                    x: panel.cx - width / 2
                    y: panel.cy + modelData.rx * panel.unit * 0.62 + 6
                    text: modelData.label
                    color: Qt.alpha(Theme.text, 0.5)
                    font.family: Theme.font
                    font.pixelSize: Math.round(11 * panel.unit)
                    font.letterSpacing: 1.5
                }
            }

            // Програми на кільцях
            Repeater {
                model: panel.orbits ? panel.found : []

                Item {
                    id: node

                    required property var modelData
                    required property int index

                    readonly property bool chosen: index === panel.chosen
                    readonly property real side: 44 * panel.unit * (panel.rings[modelData.ring]?.size ?? 1)
                    readonly property point place: panel.placeOf(modelData)
                    property bool carried: false

                    x: carried ? panel.pointer.x : place.x
                    y: carried ? panel.pointer.y : place.y
                    z: carried ? 5 : chosen ? 2 : 1

                    Image {
                        id: picture

                        visible: status === Image.Ready
                        x: -width / 2
                        y: -height / 2
                        width: node.side * (node.chosen ? 1.2 : 1)
                        height: width
                        sourceSize: Qt.size(96, 96)
                        smooth: true
                        source: node.modelData.icon ?? ""
                        opacity: node.chosen ? 1 : 0.82
                    }

                    // Значка немає: перша літера в квадраті
                    Rectangle {
                        visible: picture.status !== Image.Ready && picture.status !== Image.Loading
                        x: -width / 2
                        y: -height / 2
                        width: node.side * 0.9
                        height: width
                        color: "#1a2027"
                        border.width: 1
                        border.color: Qt.alpha(Theme.windowLit, 0.5)

                        Text {
                            anchors.centerIn: parent
                            text: (node.modelData.label ?? "?").charAt(0).toUpperCase()
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: parent.width * 0.42
                        }
                    }

                    Rectangle {
                        visible: node.chosen
                        readonly property real frame: node.side * 1.2 + 14
                        x: -frame / 2
                        y: -frame / 2
                        width: frame
                        height: frame
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.windowLit
                    }

                    Text {
                        visible: node.chosen
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: node.side * 0.6 + 12
                        text: node.modelData.label ?? ""
                        color: Theme.windowLit
                        font.family: Theme.font
                        font.pixelSize: Math.round(15 * panel.unit)
                    }

                    // Навести -- вибрати, клік -- запустити, перетягнути на стіл у барі -- запустити там
                    MouseArea {
                        readonly property real hand: Math.max(36, node.side * 1.3)

                        x: -hand / 2
                        y: -hand / 2
                        width: hand
                        height: hand
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        property point pressedAt: Qt.point(0, 0)

                        onEntered: {
                            panel.chosen = node.index;
                            panel.hovering++;
                        }
                        onExited: panel.hovering = Math.max(0, panel.hovering - 1)
                        onPressed: mouse => pressedAt = Qt.point(mouse.x, mouse.y)
                        onPositionChanged: mouse => {
                            panel.pointer = mapToItem(null, mouse.x, mouse.y);
                            if (pressed && Math.hypot(mouse.x - pressedAt.x, mouse.y - pressedAt.y) > 10)
                                node.carried = true;
                        }
                        onReleased: mouse => {
                            const spot = mapToItem(null, mouse.x, mouse.y);
                            if (!node.carried) {
                                Apps.run(node.modelData);
                            } else {
                                node.carried = false;
                                const page = panel.pageUnder(spot.x, spot.y);
                                if (page)
                                    Apps.launch(node.modelData.app, page);
                            }
                        }
                    }
                }
            }

            // Рядок пошуку
            Column {
                id: searchBox

                x: panel.cx - width / 2
                y: panel.height * 0.09
                width: 620 * panel.unit
                spacing: 8 * panel.unit

                Item {
                    width: parent.width
                    height: input.implicitHeight

                    Text {
                        id: prompt
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: Theme.windowLit
                        font: input.font
                    }

                    Text {
                        anchors.fill: input
                        visible: input.text === ""
                        text: Lang.t("Où veux-tu aller ?")
                        color: Qt.alpha(Theme.text, 0.55)
                        font: input.font
                    }

                    TextInput {
                        id: input

                        x: prompt.width + 12 * panel.unit
                        width: parent.width - x
                        color: Theme.text
                        selectionColor: Theme.windowLit
                        selectedTextColor: "#07090c"
                        font.family: Theme.font
                        font.pixelSize: Math.round(20 * panel.unit)
                        focus: true
                        onTextChanged: panel.refresh()
                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                if (panel.catalog && !panel.typing) {
                                    panel.catalog = false;
                                    panel.refresh();
                                } else {
                                    Apps.open = false;
                                }
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                panel.launch();
                                break;
                            case Qt.Key_Tab:
                                if (panel.typing) {
                                    panel.move(1);
                                } else {
                                    panel.catalog = !panel.catalog;
                                    panel.refresh();
                                }
                                break;
                            case Qt.Key_Left:
                            case Qt.Key_Up:
                                panel.move(-1);
                                break;
                            case Qt.Key_Right:
                            case Qt.Key_Down:
                                panel.move(1);
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.windowLit
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: panel.catalog ? "Tab кільця · ↑↓ вибір · Enter запуск" : "Tab усі програми · ? веб · > команда · : емодзі · 2+2 обчислити"
                    color: Qt.alpha(Theme.text, 0.5)
                    font.family: Theme.font
                    font.pixelSize: Math.round(11 * panel.unit)
                }
            }

            // Список: результати пошуку або всі програми
            ListView {
                id: list

                visible: !panel.orbits
                x: searchBox.x
                y: searchBox.y + searchBox.height + 18 * panel.unit
                width: searchBox.width
                height: panel.height * 0.92 - y
                clip: true
                model: panel.orbits ? [] : panel.found
                currentIndex: panel.chosen
                highlightMoveDuration: 80
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: index === panel.chosen

                    width: list.width
                    height: 46 * panel.unit
                    color: current ? Qt.alpha(Theme.windowLit, 0.14) : "transparent"

                    Rectangle {
                        visible: row.current
                        width: 2
                        height: parent.height
                        color: Theme.windowLit
                    }

                    Image {
                        id: rowIcon
                        visible: !row.modelData.glyph && status === Image.Ready
                        x: 14 * panel.unit
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28 * panel.unit
                        height: width
                        sourceSize: Qt.size(64, 64)
                        source: row.modelData.icon ?? ""
                    }

                    Text {
                        visible: !rowIcon.visible
                        x: 14 * panel.unit
                        width: 28 * panel.unit
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.glyph ?? (row.modelData.label ?? "?").charAt(0).toUpperCase()
                        color: Theme.text
                        font.family: row.modelData.glyph ? "" : Theme.font
                        font.pixelSize: Math.round(17 * panel.unit)
                    }

                    Text {
                        x: 56 * panel.unit
                        width: parent.width - x - kindLabel.implicitWidth - 28 * panel.unit
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.label ?? ""
                        color: row.current ? Theme.windowLit : Theme.text
                        font.family: Theme.font
                        font.pixelSize: Math.round(14 * panel.unit)
                    }

                    Text {
                        id: kindLabel
                        anchors.right: parent.right
                        anchors.rightMargin: 14 * panel.unit
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.groupOf(row.modelData)
                        color: Qt.alpha(Theme.text, 0.5)
                        font.family: Theme.font
                        font.pixelSize: Math.round(11 * panel.unit)
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: panel.chosen = row.index
                        onClicked: Apps.run(row.modelData)
                    }
                }
            }

            Text {
                visible: panel.typing && panel.found.length === 0
                x: searchBox.x
                y: list.y
                text: Lang.t("Rien dans ce ciel.")
                color: Qt.alpha(Theme.text, 0.6)
                font.family: Theme.font
                font.pixelSize: Math.round(14 * panel.unit)
            }
        }
    }
}
