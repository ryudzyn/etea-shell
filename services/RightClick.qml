pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.config

// Everything the right button can do, one list per kind of thing it lands on. With these
// you can sit back and run the desktop with the mouse alone.
Singleton {
    id: root

    // Hyprland answers after it has done the work, so ask a moment later what the window is like now
    Timer {
        id: lookAgain

        interval: 150
        onTriggered: Hyprland.refreshToplevels()
    }

    function exec(command) {
        Hyprland.dispatch(`hl.dsp.exec_cmd(${JSON.stringify(command)})`);
    }

    function pageName(page) {
        return Config.pageNames[page] || Planets.find(Planets.solar[(page - 1) % Planets.solar.length]).name;
    }

    function pageList(chosen, skip) {
        const list = [];
        for (let page = 1; page <= Config.pages; page++) {
            if (page !== skip)
                list.push({ label: pageName(page), detail: String(page).padStart(2, "0"), run: () => chosen(page) });
        }
        return list;
    }

    // ---- The empty desktop
    function desk(at, screen) {
        const widgets = Desk.catalog.filter(entry => !Desk.shown.includes(entry.type));
        Context.show("Nebula", [
            { label: Lang.t("Lancer une application"), run: () => Apps.open = true },
            { label: Lang.t("Les plus utilisées"), detail: "›", items: Apps.everything.slice().sort(Apps.byUse).slice(0, 8).map(app => ({ label: app.name, run: () => Apps.launch(app) })) },
            { label: Lang.t("Terminal"), run: () => exec("wezterm") },
            { label: Lang.t("Fichiers"), run: () => exec("nemo") },
            { label: Lang.t("Navigateur"), run: () => exec("zen") },
            { label: Lang.t("Modes"), detail: "›", items: [
                { label: Lang.t("Travail"), run: () => exec("mode-work") },
                { label: Lang.t("Études"), run: () => exec("mode-study") },
                { label: Lang.t("Jeux"), run: () => exec("mode-play") }
            ] },
            { label: Lang.t("Système solaire"), run: () => Planet.toggleOrbit() },
            { label: Lang.t("Widgets"), detail: "›", items: widgets.length ? widgets.map(entry => ({ label: entry.label, detail: "+", run: () => Desk.add(entry.type) })) : [{ label: Lang.t("Tout est déjà dans le ciel.") }] },
            { label: Lang.t("Fond d'écran spatial"), run: () => exec("nebula-space-wallpaper") },
            { label: Lang.t("Capture d'écran"), run: () => Menus.captureOpen = true },
            { label: Lang.t("Presse-papiers"), run: () => Menus.clipboardOpen = true },
            { label: Lang.t("Réglages"), run: () => Menus.settingsOpen = true },
            { label: Lang.t("Session"), run: () => Menus.sessionOpen = true }
        ], at, screen);
    }

    // ---- A window, in the overview. "go" takes you to it, the overview knows how to land.
    function windowCommand(toplevel, command) {
        const selector = `{ window = "address:0x${toplevel.address}" }`;
        Hyprland.dispatch(`hl.dsp.focus(${selector})`);
        Hyprland.dispatch(`hl.dsp.window.${command}`);
        Planet.refreshOrbit();
        lookAgain.restart();
    }

    function window(toplevel, go, at, screen) {
        const address = `address:0x${toplevel.address}`;
        const info = toplevel.lastIpcObject ?? {};
        Context.show((info.class ?? toplevel.title ?? "").split(".").pop(), [
            { label: Lang.t("Aller à cette fenêtre"), run: go },
            { label: Lang.t("Déplacer vers"), detail: "›", items: pageList(page => {
                Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${page}, follow = false, window = "${address}" })`);
                Planet.refreshOrbit();
            }, toplevel.workspace?.id) },
            { label: Lang.t("Flottante"), active: info.floating === true, run: () => windowCommand(toplevel, `float({ action = "toggle", window = "${address}" })`) },
            // Hyprland only pins a floating window
            { label: Lang.t("Sur tous les bureaux"), active: info.pinned === true, run: () => {
                if (!info.floating)
                    windowCommand(toplevel, `float({ action = "enable", window = "${address}" })`);
                windowCommand(toplevel, `pin({ action = "toggle", window = "${address}" })`);
            } },
            { label: Lang.t("Plein écran"), active: (info.fullscreen ?? 0) > 0, run: () => {
                windowCommand(toplevel, `fullscreen({ action = "toggle", window = "${address}" })`);
                go();
            } },
            { label: Lang.t("Fermer"), run: () => {
                Hyprland.dispatch(`hl.dsp.window.close({ window = "${address}" })`);
                Planet.refreshOrbit();
            } }
        ], at, screen);
    }

    // ---- A page: a planet in the system, or a number in the bar
    function page(number, go, launchThere, at, screen) {
        const windows = Hyprland.toplevels.values.filter(toplevel => toplevel.workspace?.id === number);
        const entries = [
            { label: Lang.t("Y aller"), run: go },
            { label: Lang.t("Lancer une application ici"), run: launchThere },
            { label: Lang.t("Renommer"), input: Config.pageNames[number] ?? "", done: text => {
                const names = Object.assign({}, Config.pageNames);
                if (text)
                    names[number] = text;
                else
                    delete names[number];
                Config.pageNames = names;
            } }
        ];
        // Apps may still ask to save their work, but losing a whole page deserves a second click
        if (windows.length)
            entries.push({ label: Lang.t("Fermer toutes les fenêtres"), detail: windows.length + " ›", items: [{ label: Lang.t("Oui, fermer {0}", windows.length), run: () => {
                windows.forEach(toplevel => Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${toplevel.address}" })`));
                Planet.refreshOrbit();
            } }] });
        Context.show(String(number).padStart(2, "0") + " · " + pageName(number), entries, at, screen);
    }

    // ---- An app, in the launcher
    function app(entry, at, screen) {
        const pinned = Config.pinnedApps.includes(entry.id);
        Context.show(entry.name, [
            { label: Lang.t("Lancer"), run: () => Apps.launch(entry) },
            { label: Lang.t("Lancer sur"), detail: "›", items: pageList(page => Apps.launch(entry, page), 0) },
            { label: Lang.t("Épingler en tête"), active: pinned, run: () => Config.pinnedApps = pinned ? Config.pinnedApps.filter(id => id !== entry.id) : Config.pinnedApps.concat([entry.id]) },
            // Root has to be told where the session's screen is
            { label: Lang.t("Lancer en administrateur"), run: () => {
                Apps.open = false;
                Quickshell.execDetached(["pkexec", "env", `WAYLAND_DISPLAY=${Quickshell.env("WAYLAND_DISPLAY")}`, `XDG_RUNTIME_DIR=${Quickshell.env("XDG_RUNTIME_DIR")}`, `DISPLAY=${Quickshell.env("DISPLAY") ?? ""}`].concat(entry.command));
            } }
        ], at, screen);
    }

    // ---- The bar
    function sound(full, at, screen) {
        const sink = Pipewire.defaultAudioSink;
        const outputs = Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio);
        Context.show(Lang.t("Son"), [
            { label: Lang.t("Muet"), active: sink?.audio?.muted ?? false, run: () => sink.audio.muted = !sink.audio.muted }
        ].concat(outputs.map(node => ({ label: node.description || node.name, active: node === sink, run: () => Pipewire.preferredDefaultAudioSink = node })), [
            { label: Lang.t("Tous les réglages"), run: full }
        ]), at, screen);
    }

    function bluetooth(full, at, screen) {
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter)
            return full();
        const known = Bluetooth.devices.values.filter(device => device.paired || device.connected);
        Context.show("Bluetooth", [
            { label: Lang.t("Activé"), active: adapter.enabled, run: () => adapter.enabled = !adapter.enabled }
        ].concat(adapter.enabled ? known.map(device => ({ label: device.name || device.address, active: device.connected, run: () => device.connected ? device.disconnect() : device.connect() })) : [], [
            { label: Lang.t("Tous les réglages"), run: full }
        ]), at, screen);
    }

    function network(full, at, screen) {
        Context.show(Lang.t("Réseau"), [
            { label: "Wi-Fi", active: Networking.wifiEnabled, run: () => Networking.wifiEnabled = !Networking.wifiEnabled },
            { label: Lang.t("Tous les réglages"), run: full }
        ], at, screen);
    }

    function clock(at, screen) {
        Context.show(Lang.t("Horloge"), [
            { label: Lang.t("Calendrier"), run: () => Menus.togglePanel("left") },
            { label: Lang.t("Secondes"), active: Config.clockSeconds, run: () => Config.clockSeconds = !Config.clockSeconds }
        ], at, screen);
    }
}
