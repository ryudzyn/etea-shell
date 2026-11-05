import QtQuick
import Quickshell
import qs.config
import qs.modules.bar
import qs.services

// The widgets living in the sky. Which ones, where and how big is up to Desk.
// On the desktop they answer Super: drag one to move it, Super + wheel resizes the one
// under the pointer, and a right click opens its options. A right click on the empty sky
// offers the ones that aren't out yet.
Item {
    id: root

    property bool interactive: false
    readonly property bool skyStyle: Config.widgetStyle === "sky"
    readonly property var files: skyStyle ? {
        clock: "GiantClock.qml",
        object: "SkyObject.qml",
        sky: "SkyEphemeris.qml",
        system: "SkySystem.qml",
        media: "SkyMedia.qml",
        weather: "SkyWeather.qml",
        calendar: "SkyCalendar.qml",
        tasks: "SkyTasks.qml",
        photo: "SkyPhoto.qml",
        lyrics: "SkyLyrics.qml"
    } : {
        clock: "ClockWidget.qml",
        object: "SkyObject.qml",
        sky: "SkyEphemeris.qml",
        system: "SystemWidget.qml",
        media: "MediaWidget.qml",
        weather: "WeatherWidget.qml",
        calendar: "CalendarWidget.qml",
        tasks: "TasksWidget.qml",
        photo: "PhotoWidget.qml",
        lyrics: "LyricsWidget.qml"
    }

    function origin(ax, ay) {
        return [[Item.TopLeft, Item.Top, Item.TopRight], [Item.Left, Item.Center, Item.Right], [Item.BottomLeft, Item.Bottom, Item.BottomRight]][Math.round(ay * 2)][Math.round(ax * 2)];
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        acceptedButtons: Qt.RightButton
        onPressed: mouse => RightClick.desk(Qt.point(mouse.x, mouse.y), QsWindow.window?.screen ?? null)
    }

    Repeater {
        model: Desk.shown

        Item {
            id: slot

            required property string modelData
            readonly property string type: modelData
            readonly property var place: Desk.place(type)
            readonly property real size: Desk.size(type)

            property bool dragging: false
            property point dragAt
            property point grabbedAt
            property point startedAt

            // Where the widget sits: its saved spot, or under your hand while you carry it
            x: dragging ? dragAt.x : place.x * root.width - width * place.ax
            y: dragging ? dragAt.y : place.y * root.height - height * place.ay
            width: content.width
            height: content.height
            // Sky widgets are drawn from the screen's height, so they grow crisp. The
            // celestial ones are fixed cards and get scaled around the point they stand on.
            scale: root.skyStyle ? 1 : size
            transformOrigin: root.origin(place.ax, place.ay)

            onSizeChanged: {
                if (root.interactive)
                    resized.restart();
            }

            Loader {
                id: content

                source: root.files[slot.type] ?? ""
                onLoaded: {
                    if ("sky" in item)
                        item.sky = Qt.binding(() => root.height * slot.size);
                    if ("options" in item)
                        item.options = Qt.binding(() => Desk.entry(slot.type));
                }
            }

            // Shows the widget can be handled: while Super is down over it, while carried,
            // and for a moment after a resize
            Item {
                anchors.fill: parent
                anchors.margins: -14
                opacity: slot.dragging || resized.running || (hover.hovered && (hover.point.modifiers & Qt.MetaModifier)) ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.fast }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: Qt.alpha(Theme.skyInk, 0.04)
                    border.width: 1
                    border.color: Qt.alpha(Theme.skyInk, 0.32)
                }

                Repeater {
                    model: [[0, 0], [1, 0], [1, 1], [0, 1]]

                    Star {
                        required property var modelData

                        x: modelData[0] * parent.width - size
                        y: modelData[1] * parent.height - size
                        size: 6
                        lit: true
                        animated: false
                    }
                }
            }

            Timer {
                id: resized

                interval: 700
            }

            HoverHandler {
                id: hover

                enabled: root.interactive
                onHoveredChanged: {
                    if (hovered)
                        Desk.hovered = slot.type;
                    else if (Desk.hovered === slot.type)
                        Desk.hovered = "";
                }
            }

            // Plain clicks go through to the widget's own buttons, only Super and the
            // right button stop here
            MouseArea {
                anchors.fill: parent
                enabled: root.interactive
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: slot.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
                onPressed: mouse => {
                    const at = mapToItem(root, mouse.x, mouse.y);
                    if (mouse.button === Qt.RightButton) {
                        Desk.openMenu(slot.type, at, QsWindow.window?.screen ?? null);
                        return;
                    }
                    if (!Desk.takeGrab() && !(mouse.modifiers & Qt.MetaModifier)) {
                        mouse.accepted = false;
                        return;
                    }
                    Desk.lastGesture = Date.now();
                    slot.grabbedAt = at;
                    slot.startedAt = Qt.point(slot.x, slot.y);
                    slot.dragAt = slot.startedAt;
                    slot.dragging = true;
                    Desk.carrying = true;
                }
                onPositionChanged: mouse => {
                    if (!slot.dragging)
                        return;
                    const at = mapToItem(root, mouse.x, mouse.y);
                    let x = slot.startedAt.x + at.x - slot.grabbedAt.x;
                    let y = slot.startedAt.y + at.y - slot.grabbedAt.y;
                    // The middle of the screen pulls a little, it's where the big pieces want to be
                    if (Math.abs(x + slot.width / 2 - root.width / 2) < 14)
                        x = root.width / 2 - slot.width / 2;
                    if (Math.abs(y + slot.height / 2 - root.height / 2) < 14)
                        y = root.height / 2 - slot.height / 2;
                    slot.dragAt = Qt.point(x, y);
                }
                onReleased: {
                    if (!slot.dragging)
                        return;
                    Desk.lastGesture = Date.now();
                    Desk.move(slot.type, (slot.dragAt.x + slot.width * slot.place.ax) / root.width, (slot.dragAt.y + slot.height * slot.place.ay) / root.height);
                    slot.dragging = false;
                    Desk.carrying = false;
                }
                onCanceled: {
                    slot.dragging = false;
                    Desk.carrying = false;
                }
            }
        }
    }
}
