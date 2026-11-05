import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services

// A page is a tiny constellation: one star for each open window.
// The one you're on lights up.
Item {
    id: root

    required property int pageId
    property bool active: false

    // Each page keeps its shape, so you end up recognising it
    readonly property var layout: {
        const shapes = [[[0.14, 0.62], [0.36, 0.3], [0.58, 0.68], [0.82, 0.34], [0.5, 0.92], [0.06, 0.2]], [[0.12, 0.3], [0.34, 0.7], [0.6, 0.28], [0.86, 0.64], [0.4, 0.08], [0.1, 0.84]], [[0.18, 0.74], [0.3, 0.28], [0.62, 0.52], [0.84, 0.2], [0.8, 0.82], [0.48, 0.9]]];
        return shapes[(pageId - 1) % shapes.length];
    }
    readonly property var pageWindows: Hyprland.toplevels.values.filter(t => t.workspace?.id === pageId)
    readonly property int windows: Math.min(layout.length, pageWindows.length)
    property var hovered: null
    readonly property bool lit: active || mouse.containsMouse

    // Keeps stars low enough that their halo never runs off the top of the screen
    function starY(position) {
        return (0.3 + 0.62 * position) * height;
    }

    implicitWidth: Theme.pageWidth
    implicitHeight: Theme.barHeight
    anchors.verticalCenter: parent.verticalCenter

    onWindowsChanged: links.requestPaint()
    onLitChanged: links.requestPaint()

    // The thread between the stars, same as on the login screen
    Canvas {
        id: links

        visible: !root.numbered
        anchors.fill: parent
        renderStrategy: Canvas.Immediate
        onPaint: {
            const g = getContext("2d");
            g.reset();
            if (root.windows < 2)
                return;
            g.strokeStyle = String(Theme.link);
            g.globalAlpha = root.lit ? 0.8 : 0.32;
            g.lineWidth = 1;
            g.beginPath();
            for (let i = 0; i < root.windows; i++) {
                const [px, py] = root.layout[i];
                i ? g.lineTo(px * width, root.starY(py)) : g.moveTo(px * width, root.starY(py));
            }
            g.stroke();
        }
    }

    // With numbers on, each page wears its number and the constellation steps back behind it
    readonly property bool numbered: Config.pageStyle === "numbers"

    // Compact: just the number. Pages with windows stand out, empty ones step back.
    Text {
        visible: root.numbered
        anchors.centerIn: parent
        text: root.pageId
        color: root.lit ? Theme.text : Qt.alpha(Theme.text, root.windows ? 0.8 : 0.36)
        font.family: Theme.font
        font.pixelSize: Theme.textSize + 1
        font.weight: root.active ? Font.DemiBold : Font.Normal
        font.features: { "tnum": 1 }
    }

    Star {
        visible: root.numbered && root.active
        x: root.width / 2 - size
        y: Theme.barOnTop ? root.height - size * 2 - 3 : 3
        size: 2.5
        lit: true
        animated: false
    }

    // Even an empty page keeps one tiny star, so it doesn't vanish
    Star {
        visible: root.windows === 0 && !root.numbered
        anchors.centerIn: parent
        size: root.lit ? 6 : 3
        lit: root.lit

        Behavior on size {
            NumberAnimation { duration: Theme.fast }
        }
    }

    // And here come the stars, one per window
    Repeater {
        id: stars

        model: root.windows

        Star {
            required property int index

            visible: !root.numbered

            size: root.lit ? 9 : 6
            lit: root.lit
            x: root.layout[index][0] * root.width - size
            y: root.starY(root.layout[index][1]) - size

            Behavior on size {
                NumberAnimation { duration: Theme.fast }
            }
        }
    }

    // Which window is that star? Point at it and its name shows up just below
    Row {
        id: label

        readonly property var app: root.hovered ? DesktopEntries.heuristicLookup(root.hovered.lastIpcObject?.class ?? root.hovered.wayland?.appId ?? "") : null

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barOnTop ? parent.height + 2 : -height - 2
        spacing: 6
        opacity: root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }

        Image {
            visible: source != ""
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            sourceSize: Qt.size(18, 18)
            source: label.app?.icon ? Quickshell.iconPath(label.app.icon, true) : ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: label.app?.name ?? root.hovered?.title ?? ""
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.textSize
            style: Text.Outline
            styleColor: Qt.alpha("#000000", 0.25)
        }
    }

    // One click and you're on this page
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                Planet.request(root.pageId);
            } else {
                RightClick.page(root.pageId, () => Planet.request(root.pageId), () => {
                    Planet.request(root.pageId);
                    Apps.open = true;
                }, mapToItem(null, event.x, event.y), QsWindow.window?.screen ?? null);
            }
        }
        onExited: root.hovered = null

        // The closest star wins, and you don't have to land exactly on it
        onPositionChanged: mouse => {
            if (root.numbered)
                return;
            let closest = null, distance = 18;
            for (let i = 0; i < root.windows; i++) {
                const dx = mouse.x - root.layout[i][0] * root.width, dy = mouse.y - root.starY(root.layout[i][1]);
                const here = Math.hypot(dx, dy);
                if (here < distance) {
                    distance = here;
                    closest = root.pageWindows[i];
                }
            }
            root.hovered = closest;
        }
    }
}
