import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.services

// Everything you've copied lately. Type to search, Enter puts it back on the clipboard,
// Delete forgets it. Pictures show as pictures, decoded once and kept in a cache.
Scope {
    id: root

    property bool open: false

    Connections {
        target: Menus

        function onClipboardOpenChanged() {
            root.open = Menus.clipboardOpen;
        }
    }
    property var entries: []
    property int chosen: 0
    property int thumbs: 0 // bumps once the pictures are decoded, so they reload
    property bool wiping: false // the first press on "clear all" only asks
    readonly property string cache: `${Quickshell.env("HOME")}/.cache/etea/clipboard`

    function isImage(entry) {
        return entry.text.startsWith("[[ binary data") && /(png|jpe?g|webp|gif|bmp)/.test(entry.text);
    }

    // "[[ binary data 2 MiB png 1896x1008 ]]" becomes "1896 × 1008"
    function imageSize(entry) {
        const size = entry.text.match(/(\d+)x(\d+)/);
        return size ? `${size[1]} × ${size[2]}` : "";
    }

    function forget(entry) {
        if (!entry)
            return;
        eraser.command = ["sh", "-c", 'cliphist list | awk -F "\t" -v id="$1" \'$1 == id\' | cliphist delete', "sh", entry.id];
        eraser.running = true;
        entries = entries.filter(other => other.id !== entry.id);
        chosen = Math.min(chosen, Math.max(0, found.length - 1));
    }

    function wipe() {
        if (!wiping) {
            wiping = true;
            calmDown.restart();
            return;
        }
        wiping = false;
        eraser.command = ["sh", "-c", 'cliphist wipe; rm -rf "$1"', "sh", cache];
        eraser.running = true;
        entries = [];
    }

    readonly property var found: {
        const wanted = search.text.trim().toLowerCase();
        return (wanted ? entries.filter(entry => entry.text.toLowerCase().includes(wanted)) : entries).slice(0, 40);
    }

    function pick(entry) {
        if (!entry)
            return;
        restore.command = ["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", entry.id];
        restore.running = true;
        open = false;
    }

    onOpenChanged: {
        Menus.clipboardOpen = open; // the bar's tools can open it too
        if (!open)
            return;
        search.text = "";
        chosen = 0;
        thumbs = 0;
        reader.running = true;
        search.forceActiveFocus();
    }

    GlobalShortcut {
        appid: "etea"
        name: "clipboard"
        onPressed: root.open = !root.open
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.open = !root.open;
        }
    }

    Process {
        id: restore
    }

    Process {
        id: eraser
    }

    Timer {
        id: calmDown

        interval: 3000
        onTriggered: root.wiping = false
    }

    // Decodes the pictures that aren't cached yet
    Process {
        id: decoder

        onExited: root.thumbs += 1
    }

    Process {
        id: reader

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(line => line.includes("\t")).map(line => {
                    const tab = line.indexOf("\t");
                    return { id: line.slice(0, tab), text: line.slice(tab + 1) };
                });
                const pictures = root.entries.slice(0, 60).filter(entry => root.isImage(entry)).map(entry => entry.id);
                decoder.command = ["sh", "-c", 'dir="$1"; shift; mkdir -p "$dir"; for id in "$@"; do [ -s "$dir/$id" ] || cliphist decode "$id" > "$dir/$id"; done', "sh", root.cache].concat(pictures);
                decoder.running = true;
            }
        }
    }

    PanelWindow {
        id: panel

        property real shown: root.open ? 1 : 0

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: shown > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "etea:clipboard"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Behavior on shown {
            NumberAnimation { duration: Theme.launcherFade; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.launcherShade
            opacity: panel.shown * 0.55

            MouseArea {
                anchors.fill: parent
                onPressed: root.open = false
            }
        }

        Item {
            anchors.centerIn: parent
            width: 640
            height: 560
            opacity: panel.shown
            scale: 0.95 + 0.05 * panel.shown

            HandCard {
                anchors.fill: parent
                seed: "clipboard"
                rise: 0.05
                alive: panel.visible
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                anchors.bottomMargin: 34
                spacing: 12

                RowLayout {
                    spacing: 12

                    Icon {
                        name: "clipboard"
                        size: 22
                    }

                    TextInput {
                        id: search

                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 18
                        onTextChanged: root.chosen = 0
                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.open = false;
                                break;
                            case Qt.Key_Down:
                                root.chosen = Math.min(root.found.length - 1, root.chosen + 1);
                                list.positionViewAtIndex(root.chosen, ListView.Contain);
                                break;
                            case Qt.Key_Up:
                                root.chosen = Math.max(0, root.chosen - 1);
                                list.positionViewAtIndex(root.chosen, ListView.Contain);
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.pick(root.found[root.chosen]);
                                break;
                            case Qt.Key_Delete:
                                root.forget(root.found[root.chosen]);
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }

                        Text {
                            visible: search.text === ""
                            text: Lang.t("Que cherches-tu ?")
                            color: Qt.alpha(Theme.text, 0.5)
                            font: search.font
                        }
                    }

                    Text {
                        visible: root.entries.length > 0
                        text: root.wiping ? Lang.t("Vraiment tout ?") : Lang.t("Tout effacer")
                        color: root.wiping ? "#f0947c" : Theme.windowLit
                        font.family: Theme.font
                        font.pixelSize: 12

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onPressed: root.wipe()
                        }
                    }
                }

                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: root.found

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool active: index === root.chosen
                        readonly property bool picture: root.isImage(modelData)

                        width: list.width
                        height: picture ? 92 : 40

                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: Theme.windowLit
                            opacity: row.active ? 0.16 : 0
                        }

                        Star {
                            visible: row.active
                            x: 12
                            y: parent.height / 2 - size
                            size: 6
                            lit: true
                            animated: false
                        }

                        Image {
                            visible: row.picture
                            x: 34
                            y: 8
                            width: 120
                            height: parent.height - 16
                            fillMode: Image.PreserveAspectFit
                            horizontalAlignment: Image.AlignLeft
                            asynchronous: true
                            cache: false
                            sourceSize.width: 240
                            // Only once the decoder is through, or the picture isn't there yet
                            source: row.picture && root.thumbs > 0 ? `file://${root.cache}/${row.modelData.id}?${root.thumbs}` : ""
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: row.picture ? 168 : 34
                            width: parent.width - x - 44
                            text: row.picture ? `${Lang.t("Image")} · ${root.imageSize(row.modelData)}` : row.modelData.text.startsWith("[[ binary") ? Lang.t("Fichier") : row.modelData.text
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: row.active ? Theme.text : Qt.alpha(Theme.text, 0.75)
                            font.family: Theme.font
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: pointer

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.chosen = row.index
                            onPressed: root.pick(row.modelData)
                        }

                        Icon {
                            visible: row.active
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            name: "close"
                            size: 16
                            tint: Qt.alpha(Theme.text, cross.containsMouse ? 1 : 0.5)

                            MouseArea {
                                id: cross

                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: root.forget(row.modelData)
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Lang.t("Entrée pour coller · Suppr pour retirer")
                    color: Qt.alpha(Theme.text, 0.45)
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Text {
                    visible: root.found.length === 0
                    Layout.alignment: Qt.AlignHCenter
                    text: Lang.t("Rien dans le presse-papiers.")
                    color: Qt.alpha(Theme.text, 0.6)
                    font.family: Theme.font
                    font.pixelSize: 15
                }
            }
        }
    }
}
