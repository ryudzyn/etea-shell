import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.modules.bar
import qs.services

// Your hands in orbit. Grab the sky and the planet turns with you, let go and it keeps
// spinning a little. Pick up a window to carry it to another page, click a page to land.
MouseArea {
    id: root

    required property real pivotY
    required property real zoom
    required property real lift
    required property real screenX
    required property real screenY

    property string mode: ""
    property point pressedAt: Qt.point(0, 0)
    property real lastAngle: 0
    property real lastTime: 0
    property real velocity: 0
    property var carried: null
    property int carriedFrom: -1
    property point pointer: Qt.point(0, 0)

    function cardAngle(index) {
        return Planet.shortestSteps(Planet.origin, index + 1) * Planet.step - Planet.travel + Planet.handTurn;
    }

    function pointerAngle(x, y) {
        return Math.atan2(x - width / 2, pivotY - y);
    }

    function wrap(angle) {
        return Math.atan2(Math.sin(angle), Math.cos(angle));
    }

    // Undoes a card's rotation and scale, so we can ask what's under the pointer
    function onCard(index, x, y) {
        const angle = -cardAngle(index), cos = Math.cos(angle), sin = Math.sin(angle);
        const dx = x - width / 2, dy = y - pivotY;
        const px = width / 2 + dx * cos - dy * sin;
        const py = pivotY + dx * sin + dy * cos - lift;
        return Qt.point(width / 2 + (px - width / 2) / zoom, height + (py - height) / zoom);
    }

    function pageAt(x, y) {
        for (let i = 0; i < Config.pages; i++) {
            const p = onCard(i, x, y);
            if (p.x >= 0 && p.x <= width && p.y >= 0 && p.y <= height)
                return i;
        }
        return -1;
    }

    function windowAt(index, x, y) {
        if (index < 0)
            return null;
        const p = onCard(index, x, y);
        return (Planet.orbitPages[index] ?? []).find(window => {
            const info = window.lastIpcObject, left = info.at[0] - screenX, top = info.at[1] - screenY;
            return p.x >= left && p.x <= left + info.size[0] && p.y >= top && p.y <= top + info.size[1];
        }) ?? null;
    }

    // Which page the pointer is pointing at, even out in empty space
    function pageToward(x, y) {
        const here = pointerAngle(x, y);
        let best = 0, closest = 10;
        for (let i = 0; i < Config.pages; i++) {
            const gap = Math.abs(wrap(here - cardAngle(i)));
            if (gap < closest) {
                closest = gap;
                best = i;
            }
        }
        return best;
    }

    enabled: Planet.orbiting && !Planet.inSystem && Planet.altitude === 1
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: mode === "spin" ? Qt.ClosedHandCursor : Planet.hoveredPage >= 0 ? Qt.PointingHandCursor : Qt.OpenHandCursor

    onExited: Planet.hoveredPage = -1

    onPressed: mouse => {
        mode = "";
        pressedAt = Qt.point(mouse.x, mouse.y);
        lastAngle = pointerAngle(mouse.x, mouse.y);
        lastTime = Date.now();
        velocity = 0;
        carriedFrom = pageAt(mouse.x, mouse.y);
        carried = windowAt(carriedFrom, mouse.x, mouse.y);
    }

    onPositionChanged: mouse => {
        pointer = Qt.point(mouse.x, mouse.y);
        if (!pressed) {
            Planet.hoveredPage = pageAt(mouse.x, mouse.y);
            return;
        }

        if (!mode && Math.hypot(mouse.x - pressedAt.x, mouse.y - pressedAt.y) > 10) {
            mode = carried ? "carry" : "spin";
            Planet.holdSpin();
        }

        if (mode === "spin") {
            const angle = pointerAngle(mouse.x, mouse.y), now = Date.now();
            const delta = wrap(angle - lastAngle);
            Planet.handTurn += delta;
            velocity = delta / Math.max(1, now - lastTime) * 1000;
            lastAngle = angle;
            lastTime = now;
        } else if (mode === "carry") {
            Planet.hoveredPage = pageToward(mouse.x, mouse.y);
        }
    }

    onReleased: mouse => {
        if (mode === "spin") {
            Planet.fling(velocity);
        } else if (mode === "carry") {
            const page = pageToward(mouse.x, mouse.y);
            if (page !== carriedFrom) {
                Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${Planet.orbitStart + page}, follow = false, window = "address:0x${carried.address}" })`);
                Planet.refreshOrbit();
            }
        } else if (mouse.button === Qt.RightButton) {
            const spot = mapToItem(null, mouse.x, mouse.y), onScreen = QsWindow.window?.screen ?? null;
            const page = Planet.orbitStart + carriedFrom;
            if (carried) {
                const window = carried;
                RightClick.window(window, () => {
                    Planet.leaveOrbit(window.workspace?.id ?? page);
                    Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${window.address}" })`);
                }, spot, onScreen);
            } else if (carriedFrom >= 0) {
                RightClick.page(page, () => Planet.leaveOrbit(page), () => {
                    Planet.leaveOrbit(page);
                    Apps.open = true;
                }, spot, onScreen);
            }
        } else if (mouse.button === Qt.MiddleButton) {
            if (carried) {
                Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${carried.address}" })`);
                Planet.refreshOrbit();
            }
        } else if (carriedFrom >= 0) {
            Planet.leaveOrbit(Planet.orbitStart + carriedFrom);
        }
        mode = "";
        carried = null;
    }

    onWheel: wheel => Planet.nudge(wheel.angleDelta.y > 0 ? 1 : -1)

    // The window you're carrying, reduced to its star and its name
    Item {
        x: root.pointer.x
        y: root.pointer.y
        visible: root.mode === "carry"

        Star {
            x: -size
            y: -size
            size: 18
            lit: true
            animated: false
        }

        Text {
            x: 26
            y: -10
            text: root.carried?.lastIpcObject?.class ?? ""
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
        }
    }
}
