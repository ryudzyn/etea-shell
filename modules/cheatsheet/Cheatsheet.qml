import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.modules.bar
import qs.services

// Every shortcut in one place: ETEA's own first, then the ones from your Hyprland config
// that carry a description, grouped the way the description names them ("Window: Move").
// Read from Hyprland each time it opens, so it never goes stale. Super + / or Escape closes.
Scope {
    id: root

    property bool open: false
    property var groups: []
    property string search: ""

    // ETEA's shortcuts, set up by scripts/dev.sh. mods and key match Hyprland's own names.
    readonly property var own: [
        { mods: 64, key: "SUPER_L", keys: "Super", label: "Запуск програм" },
        { mods: 64, key: "Tab", keys: "Super + Tab", label: "Сонячна система: вибір столу" },
        { mods: 65, key: "Tab", keys: "Super + Shift + Tab", label: "Назад із Сонячної системи" },
        { mods: 64, key: "code:10", keys: "Super + 1 … 0", label: "Перелетіти на стіл" },
        { mods: 68, key: "Right", keys: "Ctrl + Super + ← →", label: "Сусідній стіл" },
        { mods: 64, key: "mouse_up", keys: "Super + коліщатко", label: "Сусідній стіл, а над віджетом -- його розмір" },
        { mods: 64, key: "A", keys: "Super + A", label: "Ліва панель: календар, завдання, таймер" },
        { mods: 64, key: "N", keys: "Super + N", label: "Центр керування і сповіщення" },
        { mods: 64, key: "Q", keys: "Super + Q", label: "Закрити вікно" },
        { mods: 64, key: "V", keys: "Super + V", label: "Історія буфера обміну" },
        { mods: 65, key: "S", keys: "Super + Shift + S", label: "Захоплення екрана, Tab -- запис" },
        { mods: 64, key: "Comma", keys: "Super + ,", label: "Налаштування" },
        { mods: 64, key: "Slash", keys: "Super + /", label: "Ці підказки" },
        { mods: 64, key: "mouse:272", keys: "Super + перетягування", label: "Посунути віджет або вікно" }
    ]
    // Ті самі дії, що вже описані рядком вище: у шпаргалці другий раз не потрібні
    readonly property var repeats: ["68 Left", "64 mouse_down", "64 SUPER_R"]

    readonly property var shown: {
        const wanted = search.trim().toLowerCase();
        if (!wanted)
            return groups;
        return groups.map(group => ({ name: group.name, binds: group.binds.filter(bind => `${bind.keys} ${bind.label}`.toLowerCase().includes(wanted)) })).filter(group => group.binds.length);
    }

    // Three columns, each group joining the shortest one, so no holes open between them
    readonly property var columns: {
        const result = [[], [], []], heights = [0, 0, 0];
        for (const group of shown) {
            const shortest = heights.indexOf(Math.min(...heights));
            result[shortest].push(group);
            heights[shortest] += group.binds.length + 3;
        }
        return result;
    }

    // Hyprland's names, the way a keyboard reads them
    function keyName(key) {
        const named = {
            "mouse:272": Lang.t("Clic gauche"),
            "mouse:273": Lang.t("Clic droit"),
            "mouse:274": Lang.t("Clic molette"),
            "mouse:275": Lang.t("Bouton arrière"),
            "mouse:276": Lang.t("Bouton avant"),
            "mouse_up": Lang.t("Molette ↑"),
            "mouse_down": Lang.t("Molette ↓"),
            "Return": Lang.t("Entrée"),
            "Escape": Lang.t("Échap"),
            "Delete": Lang.t("Suppr"),
            "Print": Lang.t("Impr"),
            "Slash": "/",
            "Comma": ",",
            "Period": ".",
            "Space": Lang.t("Espace"),
            "Left": "←",
            "Right": "→",
            "Up": "↑",
            "Down": "↓",
            "Page_Up": Lang.t("Page ↑"),
            "Page_Down": Lang.t("Page ↓")
        };
        if (named[key])
            return named[key];
        // Number row keycodes: 10 is 1, 19 is 0
        const code = key.match(/^code:(\d+)$/);
        if (code && code[1] >= 10 && code[1] <= 19)
            return String((code[1] - 9) % 10);
        return key.replace(/^XF86/, "").replace(/_/g, " ");
    }

    function keysOf(bind) {
        const mods = [];
        if (bind.modmask & 64)
            mods.push("Super");
        if (bind.modmask & 4)
            mods.push("Ctrl");
        if (bind.modmask & 8)
            mods.push("Alt");
        if (bind.modmask & 1)
            mods.push(Lang.t("Maj"));
        return mods.concat([keyName(bind.key)]).join(" + ");
    }

    function build(binds) {
        const taken = own.map(bind => `${bind.mods} ${bind.key}`).concat(repeats);
        const found = [{ name: "Оболонка", binds: own }];
        for (const bind of binds) {
            if (!bind.description || taken.includes(`${bind.modmask} ${bind.key}`))
                continue;
            const split = bind.description.indexOf(":");
            const name = split > 0 ? bind.description.slice(0, split).trim() : Lang.t("Autres");
            const label = split > 0 ? bind.description.slice(split + 1).trim() : bind.description;
            const group = found.find(other => other.name === name);
            const entry = { keys: keysOf(bind), label: label };
            group ? group.binds.push(entry) : found.push({ name: name, binds: [entry] });
        }
        groups = found;
    }

    onOpenChanged: {
        if (!open)
            return;
        search = "";
        reader.running = true;
    }

    GlobalShortcut {
        appid: "etea"
        name: "cheatsheet"
        onPressed: root.open = !root.open
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            root.open = !root.open;
        }
    }

    Process {
        id: reader

        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.build(JSON.parse(text));
                } catch (error) {
                    root.build([]);
                }
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
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "etea:cheatsheet"
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

        onVisibleChanged: {
            if (visible)
                field.forceActiveFocus();
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.launcherShade
            opacity: panel.shown * 0.85

            MouseArea {
                anchors.fill: parent
                onPressed: root.open = false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: Theme.barReserve + 30
            anchors.bottomMargin: 30
            // The scrolling area reaches a little past the content, so the cards' stars and
            // ink have room; the margins give that room back to keep everything in place
            readonly property int room: 16

            anchors.leftMargin: 60 - room
            anchors.rightMargin: 60 - room
            spacing: 22 - room
            opacity: panel.shown

            transform: Translate {
                y: (1 - panel.shown) * 16
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: parent.room
                Layout.rightMargin: parent.room
                spacing: 18

                Text {
                    text: Lang.t("Raccourcis")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 30
                    font.weight: Font.Light
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 320
                    implicitHeight: 38
                    radius: 0
                    color: Qt.alpha(Theme.windowLit, 0.1)

                    TextInput {
                        id: field

                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                        clip: true
                        onTextChanged: root.search = text
                        Keys.onEscapePressed: root.open = false
                    }

                    Text {
                        visible: field.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        x: 14
                        text: Lang.t("Chercher un raccourci")
                        color: Qt.alpha(Theme.text, 0.4)
                        font.family: Theme.font
                        font.pixelSize: 14
                    }
                }
            }

            // Three columns of constellations, filled from the shortest one
            Flickable {
                id: scroller

                readonly property int room: parent.room

                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: flow.implicitHeight + room * 2
                clip: true

                RowLayout {
                    id: flow

                    x: scroller.room
                    y: scroller.room
                    width: parent.width - scroller.room * 2
                    spacing: 18

                    Repeater {
                        model: root.columns

                        ColumnLayout {
                            id: column

                            required property var modelData

                            Layout.preferredWidth: (flow.width - flow.spacing * 2) / 3
                            Layout.alignment: Qt.AlignTop
                            spacing: 18

                            Repeater {
                                model: column.modelData

                                Item {
                                    id: group

                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: list.implicitHeight + 44

                                    HandCard {
                                        anchors.fill: parent
                                        seed: group.modelData.name
                                        rise: 0.04
                                        starSpacing: 220
                                        alive: panel.visible
                                    }

                                    ColumnLayout {
                                        id: list

                                        x: 20
                                        y: 20
                                        width: parent.width - 40
                                        spacing: 7

                                        Text {
                                            Layout.bottomMargin: 4
                                            text: group.modelData.name
                                            color: Theme.windowLit
                                            font.family: Theme.font
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                        }

                                        Repeater {
                                            model: group.modelData.binds

                                            RowLayout {
                                                id: bind

                                                required property var modelData

                                                Layout.fillWidth: true
                                                spacing: 12

                                                Rectangle {
                                                    Layout.alignment: Qt.AlignTop
                                                    implicitWidth: keys.implicitWidth + 16
                                                    implicitHeight: 24
                                                    radius: 0
                                                    color: Qt.alpha(Theme.windowLit, 0.14)
                                                    border.width: 1
                                                    border.color: Qt.alpha(Theme.windowLit, 0.3)

                                                    Text {
                                                        id: keys

                                                        anchors.centerIn: parent
                                                        text: bind.modelData.keys
                                                        color: Theme.text
                                                        font.family: Theme.font
                                                        font.pixelSize: 11
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: bind.modelData.label
                                                    wrapMode: Text.WordWrap
                                                    color: Qt.alpha(Theme.text, 0.8)
                                                    font.family: Theme.font
                                                    font.pixelSize: 12
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
