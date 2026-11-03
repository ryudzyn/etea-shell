import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar

// Pieces you pick up and drop into zones: the bar's three ends, or shown and hidden.
// Dropping one between two others puts it right there.
Item {
    id: board

    property var zones: [] // { id, label, items: [ids] }
    property var choices: [] // { id, label, icon }
    property int columns: 1
    property bool spanLast: false // the last zone takes a whole row, for the leftovers
    property bool clickMoves: false // with two zones, a click sends a piece to the other one

    // What's being carried, and where it would land
    property string carried: ""
    property point carriedAt: Qt.point(0, 0)
    property string landingZone: ""

    signal changed(var zones)

    function choice(id) {
        return choices.find(entry => entry.id === id) ?? { id: id, label: id, icon: "" };
    }

    function move(id, zoneId, index) {
        const next = zones.map(zone => ({ id: zone.id, label: zone.label, items: zone.items.filter(item => item !== id) }));
        const target = next.find(zone => zone.id === zoneId);
        if (!target)
            return;
        target.items.splice(Math.max(0, Math.min(index, target.items.length)), 0, id);
        changed(next);
    }

    function zoneAt(point) {
        for (let i = 0; i < zoneRepeater.count; i++) {
            const zone = zoneRepeater.itemAt(i), at = zone.mapToItem(board, 0, 0);
            if (point.x >= at.x && point.x <= at.x + zone.width && point.y >= at.y && point.y <= at.y + zone.height)
                return zone;
        }
        return null;
    }

    // Counts the pieces that come before the drop point, reading like a line of text
    function indexAt(zone, point) {
        let index = 0;
        for (const chip of zone.chips()) {
            if (chip.chipId === carried)
                continue;
            const center = chip.mapToItem(board, chip.width / 2, chip.height / 2);
            if (center.y < point.y - chip.height / 2 || (Math.abs(center.y - point.y) <= chip.height / 2 && center.x < point.x))
                index++;
        }
        return index;
    }

    implicitHeight: grid.implicitHeight
    Layout.fillWidth: true

    GridLayout {
        id: grid

        width: parent.width
        columns: board.columns
        rowSpacing: 10
        columnSpacing: 10

        Repeater {
            id: zoneRepeater

            model: board.zones

            Rectangle {
                id: zone

                required property var modelData
                required property int index
                readonly property string zoneId: modelData.id

                function chips() {
                    return flow.children.filter(child => child.chipId !== undefined);
                }

                // Zones on the same row keep the same height, so nothing shifts while you drag
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                Layout.columnSpan: board.spanLast && index === board.zones.length - 1 ? board.columns : 1
                Layout.preferredHeight: Math.max(76, flow.implicitHeight + 46)
                radius: 0
                color: Qt.alpha(Theme.windowLit, board.landingZone === zoneId ? 0.16 : 0.05)
                border.width: 1
                border.color: Qt.alpha(Theme.windowLit, board.landingZone === zoneId ? 0.6 : 0.14)

                Behavior on color {
                    ColorAnimation { duration: Theme.fast }
                }

                Text {
                    x: 14
                    y: 10
                    text: zone.modelData.label
                    color: Qt.alpha(Theme.text, 0.6)
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Flow {
                    id: flow

                    x: 12
                    y: 32
                    width: parent.width - 24
                    spacing: 8

                    Repeater {
                        model: zone.modelData.items

                        Chip {
                            required property string modelData

                            chipId: modelData
                            entry: board.choice(modelData)
                            opacity: board.carried === modelData ? 0.25 : 1
                        }
                    }
                }
            }
        }
    }

    // The piece in your hand
    Chip {
        visible: board.carried !== ""
        x: board.carriedAt.x - width / 2
        y: board.carriedAt.y - height / 2
        z: 10
        entry: board.choice(board.carried)
        scale: 1.08
        held: true
    }

    component Chip: Item {
        id: chip

        property string chipId: ""
        property var entry: ({})
        property bool held: false
        property point pressedAt: Qt.point(0, 0)

        implicitWidth: content.implicitWidth + 26
        implicitHeight: 36

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: Qt.alpha(Theme.windowLit, chip.held ? 0.32 : pointer.containsMouse ? 0.22 : 0.13)
            border.width: chip.held ? 1 : 0
            border.color: Qt.alpha(Theme.windowLit, 0.7)
        }

        Row {
            id: content

            anchors.centerIn: parent
            spacing: 8

            Icon {
                visible: chip.entry.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: chip.entry.icon ?? ""
                size: 17
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.entry.label ?? ""
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
            }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            enabled: !chip.held
            hoverEnabled: true
            preventStealing: true
            cursorShape: board.carried ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: mouse => chip.pressedAt = Qt.point(mouse.x, mouse.y)
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                if (!board.carried && Math.hypot(mouse.x - chip.pressedAt.x, mouse.y - chip.pressedAt.y) < 5)
                    return;
                board.carried = chip.chipId;
                board.carriedAt = chip.mapToItem(board, mouse.x, mouse.y);
                board.landingZone = board.zoneAt(board.carriedAt)?.zoneId ?? "";
            }
            // Moving rebuilds the chips, this one included, so tidy up before anything moves
            onReleased: {
                const owner = board, carried = board.carried, at = board.carriedAt, id = chip.chipId;
                owner.carried = "";
                owner.landingZone = "";
                if (carried) {
                    const zone = owner.zoneAt(at);
                    if (zone)
                        owner.move(carried, zone.zoneId, owner.indexAt(zone, at));
                } else if (owner.clickMoves) {
                    const other = owner.zones.find(zone => !zone.items.includes(id));
                    if (other)
                        owner.move(id, other.id, other.items.length);
                }
            }
            onCanceled: {
                board.carried = "";
                board.landingZone = "";
            }
        }
    }
}
