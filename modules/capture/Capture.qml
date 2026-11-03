import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.bar

// Take a piece of the screen. Everything freezes, then you draw a zone with stars on its
// corners, click a window, or press Enter for the whole screen. A photo lands in your
// pictures and on your clipboard, a video in your videos. Tab switches between them.
Scope {
    id: root

    property bool open: false

    Connections {
        target: Menus

        function onCaptureOpenChanged() {
            // Asking for a capture while filming means: that's enough
            if (Menus.captureOpen && Recorder.recording) {
                Recorder.stop();
                Menus.captureOpen = false;
                return;
            }
            root.open = Menus.captureOpen;
        }
    }

    property string mode: "photo" // or "video"
    property bool withSound: false
    property point pointer: Qt.point(-1, -1)
    property var pending: null // what to do once the overlay is gone

    // The window under the pointer, the most recently used one if they overlap
    readonly property rect windowZone: {
        const screen = panel.screen;
        if (!screen || pointer.x < 0)
            return Qt.rect(0, 0, 0, 0);
        const x = pointer.x + screen.x, y = pointer.y + screen.y;
        const under = Hyprland.toplevels.values.filter(t => {
            const info = t.lastIpcObject;
            return t.workspace?.id === Planet.current && info?.size && x >= info.at[0] && x < info.at[0] + info.size[0] && y >= info.at[1] && y < info.at[1] + info.size[1];
        }).sort((a, b) => a.lastIpcObject.focusHistoryID - b.lastIpcObject.focusHistoryID)[0];
        const info = under?.lastIpcObject;
        return info ? Qt.rect(info.at[0] - screen.x, info.at[1] - screen.y, info.size[0], info.size[1]) : Qt.rect(0, 0, 0, 0);
    }
    readonly property rect shownZone: zone.width > 0 ? zone : windowZone
    property point start: Qt.point(0, 0)
    property point end: Qt.point(0, 0)
    property bool dragging: false

    readonly property rect zone: Qt.rect(Math.min(start.x, end.x), Math.min(start.y, end.y), Math.abs(end.x - start.x), Math.abs(end.y - start.y))

    function take(z) {
        const screen = panel.screen;
        const geometry = `${Math.round(screen.x + z.x)},${Math.round(screen.y + z.y)} ${Math.round(z.width)}x${Math.round(z.height)}`;
        pending = { geometry: geometry, video: mode === "video", sound: withSound };
        open = false;
        settle.restart();
    }

    function wholeScreen() {
        take(Qt.rect(0, 0, panel.width, panel.height));
    }

    onOpenChanged: {
        Menus.captureOpen = open; // the bar's tools can open it too
        dragging = false;
        start = Qt.point(0, 0);
        end = Qt.point(0, 0);
        pointer = Qt.point(-1, -1);
        if (open)
            Hyprland.refreshToplevels();
    }

    GlobalShortcut {
        appid: "etea"
        name: "capture"
        onPressed: {
            if (Recorder.recording)
                Recorder.stop();
            else
                root.open = !root.open;
        }
    }

    IpcHandler {
        target: "capture"

        function toggle(): void {
            if (Recorder.recording)
                Recorder.stop();
            else
                root.open = !root.open;
        }
    }

    // Let the overlay leave the screen before taking the picture
    Timer {
        id: settle

        interval: 120
        onTriggered: {
            const job = root.pending;
            if (!job)
                return;
            if (job.video) {
                Recorder.start(job.geometry, job.sound);
            } else {
                saver.command = ["sh", "-c", `dir="$(xdg-user-dir PICTURES)/Captures"; mkdir -p "$dir"; file="$dir/etea-$(date +%Y%m%d-%H%M%S).png"; grim -g "$1" "$file" && wl-copy < "$file" && notify-send -a "$2" -i "$file" "$3" "$file"`, "sh", job.geometry, Lang.t("Capture"), Lang.t("Capture enregistrée")];
                saver.running = true;
            }
            root.pending = null;
        }
    }

    Process {
        id: saver
    }

    PanelWindow {
        id: panel

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:capture"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Loader {
            anchors.fill: parent
            active: root.open

            sourceComponent: ScreencopyView {
                captureSource: panel.screen
                live: false
            }
        }

        // The dimmed screen, with the chosen zone left clear
        Item {
            anchors.fill: parent

            Rectangle { x: 0; y: 0; width: parent.width; height: root.shownZone.y; color: "#8c05060e" }
            Rectangle { x: 0; y: root.shownZone.y + root.shownZone.height; width: parent.width; height: parent.height - y; color: "#8c05060e" }
            Rectangle { x: 0; y: root.shownZone.y; width: root.shownZone.x; height: root.shownZone.height; color: "#8c05060e" }
            Rectangle { x: root.shownZone.x + root.shownZone.width; y: root.shownZone.y; width: parent.width - x; height: root.shownZone.height; color: "#8c05060e" }
        }

        Rectangle {
            visible: root.shownZone.width > 0
            x: root.shownZone.x
            y: root.shownZone.y
            width: root.shownZone.width
            height: root.shownZone.height
            color: "transparent"
            border.width: 1
            border.color: Theme.windowLit
        }

        Repeater {
            model: [[0, 0], [1, 0], [1, 1], [0, 1]]

            Star {
                required property var modelData

                visible: root.shownZone.width > 0
                x: root.shownZone.x + root.shownZone.width * modelData[0] - size
                y: root.shownZone.y + root.shownZone.height * modelData[1] - size
                size: 9
                lit: true
                animated: false
            }
        }

        Text {
            visible: root.shownZone.width > 0
            x: root.shownZone.x
            y: Math.max(8, root.shownZone.y - 30)
            text: `${Math.round(root.shownZone.width)} × ${Math.round(root.shownZone.height)}`
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }

        Column {
            visible: !root.dragging && root.shownZone.width === 0
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Lang.t("Trace une zone, clique sur une fenêtre")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 24
                font.weight: Font.Light
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Lang.t("Entrée pour tout l'écran · Tab pour photo ou vidéo")
                color: Qt.alpha(Theme.text, 0.6)
                font.family: Theme.font
                font.pixelSize: 14
            }
        }

        MouseArea {
            anchors.fill: parent
            focus: true
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            onPressed: mouse => {
                root.start = Qt.point(mouse.x, mouse.y);
                root.end = root.start;
                root.dragging = true;
            }
            onPositionChanged: mouse => {
                root.pointer = Qt.point(mouse.x, mouse.y);
                if (root.dragging)
                    root.end = Qt.point(mouse.x, mouse.y);
            }
            // A drag is a zone, a click is the window under it, or the whole screen
            onReleased: {
                root.dragging = false;
                if (root.zone.width > 4 && root.zone.height > 4)
                    root.take(root.zone);
                else if (root.windowZone.width > 0)
                    root.take(root.windowZone);
                else
                    root.wholeScreen();
            }
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    root.open = false;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.wholeScreen();
                    break;
                case Qt.Key_Tab:
                    root.mode = root.mode === "photo" ? "video" : "photo";
                    break;
                case Qt.Key_S:
                    root.withSound = !root.withSound;
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }

        // Photo or video, and for a video whether the sound goes with it
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.barOnTop ? Theme.barReserve + 14 : 28
            spacing: 8

            Repeater {
                model: [
                    { id: "photo", label: Lang.t("Photo"), on: root.mode === "photo" },
                    { id: "video", label: Lang.t("Vidéo"), on: root.mode === "video" },
                    { id: "sound", label: Lang.t("Avec le son"), on: root.withSound, hidden: root.mode !== "video" }
                ]

                Rectangle {
                    required property var modelData

                    visible: !modelData.hidden
                    width: label.implicitWidth + 30
                    height: 34
                    radius: 0
                    color: Qt.alpha(Theme.windowLit, modelData.on ? 0.3 : 0.1)
                    border.width: 1
                    border.color: Qt.alpha(Theme.windowLit, modelData.on ? 0.7 : 0.2)

                    Text {
                        id: label

                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            if (parent.modelData.id === "sound")
                                root.withSound = !root.withSound;
                            else
                                root.mode = parent.modelData.id;
                        }
                    }
                }
            }
        }
    }
}
