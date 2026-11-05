pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Your sky of apps: what's installed, what you open most, and how to find anything.
// Typing also does sums, ">" runs a command, ":" finds an emoji, "?" asks the web.
Singleton {
    id: root

    property bool open: false
    property string startWith: "" // what the search box opens with, ":" for the emoji
    property var uses: ({})
    property var emoji: [] // [glyph, names, plain names], split the first time ":" is typed

    readonly property var everything: DesktopEntries.applications.values.filter(app => !app.noDisplay)

    // How the sky is divided into constellations
    readonly property var families: [
        { name: Lang.t("Création"), categories: ["Graphics", "AudioVideo", "Audio", "Video"] },
        { name: "Code", categories: ["Development"] },
        { name: Lang.t("Internet"), categories: ["Network", "WebBrowser", "Chat", "Email"] },
        { name: Lang.t("Travail"), categories: ["Office", "Education", "Science"] },
        { name: Lang.t("Système"), categories: ["System", "Settings", "Utility", "FileTools", "Monitor"] },
        { name: Lang.t("Jeux"), categories: ["Game"] },
        { name: Lang.t("Le reste"), categories: [] }
    ]

    function usesOf(app) {
        return uses[app.id] ?? 0;
    }

    function byUse(a, b) {
        return Config.pinnedApps.includes(b.id) - Config.pinnedApps.includes(a.id) || usesOf(b) - usesOf(a) || a.name.localeCompare(b.name);
    }

    function familyOf(app) {
        const found = families.findIndex(family => family.categories.some(category => app.categories.includes(category)));
        return found < 0 ? families.length - 1 : found;
    }

    function appEntry(app) {
        return { kind: "app", label: app.name, icon: Quickshell.iconPath(app.icon, true), app: app };
    }

    // Nothing typed: the whole map, every app, your favourites at the heart of each constellation
    function map() {
        return families.map((family, index) => ({
            name: family.name,
            stars: everything.filter(app => familyOf(app) === index).sort(byUse).map(appEntry)
        }));
    }

    // Starting with what you typed beats a word starting with it, which beats anywhere at all
    function score(app, text) {
        const name = app.name.toLowerCase();
        if (name.startsWith(text))
            return 40;
        if (name.split(/\s+/).some(word => word.startsWith(text)))
            return 30;
        if (name.includes(text))
            return 20;
        const extra = `${app.genericName} ${app.comment} ${app.keywords.join(" ")}`.toLowerCase();
        return extra.includes(text) ? 10 : 0;
    }

    // A sum, if what you typed is one. Only digits, operators and a few known functions
    // ever reach the evaluation: sqrt, sin, cos, tan, log, ln, abs, round, pi, e…
    readonly property var maths: ({ sqrt: "Math.sqrt", sin: "Math.sin", cos: "Math.cos", tan: "Math.tan", asin: "Math.asin", acos: "Math.acos", atan: "Math.atan", log: "Math.log10", ln: "Math.log", abs: "Math.abs", round: "Math.round", floor: "Math.floor", ceil: "Math.ceil", pi: "Math.PI", e: "Math.E" })

    function sum(text) {
        const cleaned = text.replace(/,/g, ".").replace(/\^/g, "**").replace(/π/g, "pi").replace(/√/g, "sqrt").trim().toLowerCase();
        const words = /\b(sqrt|sin|cos|tan|asin|acos|atan|log|ln|abs|round|floor|ceil|pi|e)\b/g;
        const bare = cleaned.replace(words, "");
        // An operator or a function call makes it a sum, a lone "e" is just the start of a word
        if (!/^[\d\s+\-*/().%]*$/.test(bare) || !(/[+\-*/%]/.test(bare) || /[a-z]\s*\(/.test(cleaned)) || !/\d|pi|\be\b/.test(cleaned))
            return null;
        try {
            const value = new Function(`return (${cleaned.replace(words, word => root.maths[word])})`)();
            return Number.isFinite(value) ? Math.round(value * 1e6) / 1e6 : null;
        } catch (error) {
            return null;
        }
    }

    // Accents don't count when looking for a word: "coeur" finds "cœur", "ete" finds "été"
    function plain(text) {
        return text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/œ/g, "oe");
    }

    function findEmoji(text) {
        if (!emoji.length)
            emoji = emojiFile.text().split("\n").filter(line => line).map(line => {
                const [glyph, names] = line.split("\t");
                return [glyph, names.split(" | "), plain(names)];
            });
        const words = plain(text).split(/\s+/).filter(word => word);
        const french = Lang.code === "fr";
        // Its own name first, then the words people tag it with
        const named = entry => words.every(word => plain(`${entry[1][0]} ${entry[1][1] ?? ""}`).includes(word)) ? 1 : 0;
        return emoji.filter(entry => words.every(word => entry[2].includes(word))).sort((a, b) => named(b) - named(a)).slice(0, Config.launcherStars).map(entry => ({
            kind: "emoji",
            glyph: entry[0],
            label: (french ? entry[1][1] : entry[1][0]) || entry[1][0],
            value: entry[0]
        }));
    }

    function webEntry(text) {
        const asset = "file://" + Quickshell.shellPath("assets/icons/search.svg");
        return { kind: "web", label: Lang.t("Chercher « {0} » sur le web", text), icon: asset, query: text };
    }

    // Typing: sums, commands, open windows and apps, whatever fits best first
    function search(text) {
        const typed = text.trim(), wanted = typed.toLowerCase(), found = [];
        const asset = name => "file://" + Quickshell.shellPath(`assets/icons/${name}.svg`);
        // Nothing typed matches every window there is, that's the map's job, not a search
        if (!typed)
            return [];

        if (typed.startsWith(">") && typed.length > 1)
            return [{ kind: "command", label: Lang.t("Lancer {0}", typed.slice(1).trim()), icon: asset("play"), command: typed.slice(1).trim() }];
        if (typed.startsWith(":") && typed.length > 1)
            return findEmoji(typed.slice(1));
        if (typed.startsWith("?") && typed.length > 1)
            return [webEntry(typed.slice(1).trim())];

        const result = sum(typed);
        if (result !== null)
            found.push({ kind: "sum", label: `= ${result}`, icon: asset("search"), value: String(result) });

        for (const window of Hyprland.toplevels.values) {
            const title = window.title ?? "", kind = window.lastIpcObject?.class ?? "";
            if (title.toLowerCase().includes(wanted) || kind.toLowerCase().includes(wanted)) {
                // Without a class Hyprland can't say which app it is, and a guess goes badly wrong
                const app = kind ? DesktopEntries.heuristicLookup(kind) : null;
                found.push({ kind: "window", label: Lang.t("Aller à {0}", app?.name ?? title), icon: Quickshell.iconPath(app?.icon ?? "", true), window: window });
            }
        }

        const apps = everything.map(app => ({ app: app, score: score(app, wanted) })).filter(match => match.score > 0);
        apps.sort((a, b) => b.score - a.score || byUse(a.app, b.app));
        const all = found.concat(apps.map(match => appEntry(match.app))).slice(0, Config.launcherStars);
        // Nothing much matched: the web is the last star
        if (all.length < Config.launcherStars && typed.length > 1 && result === null)
            all.push(webEntry(typed));
        return all;
    }

    function launch(app, page) {
        const next = Object.assign({}, uses);
        next[app.id] = (next[app.id] ?? 0) + 1;
        uses = next;
        memory.setText(JSON.stringify(next));
        open = false;
        if (page) {
            Planet.request(page);
            pending = app;
            afterSpin.restart();
        } else {
            app.execute();
        }
    }

    function run(entry) {
        open = false;
        switch (entry.kind) {
        case "app":
            launch(entry.app);
            break;
        case "window":
            Planet.request(entry.window.workspace?.id ?? Planet.current);
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${entry.window.address}" })`);
            break;
        case "sum":
        case "emoji":
            copier.exec(["wl-copy", entry.value]);
            break;
        case "web":
            Qt.openUrlExternally(`https://duckduckgo.com/?q=${encodeURIComponent(entry.query)}`);
            break;
        case "command":
            Hyprland.dispatch(`hl.dsp.exec_cmd(${JSON.stringify(entry.command)})`);
            break;
        }
    }

    property var pending: null

    // Dropped on another page: arrive there first, then open it
    Timer {
        id: afterSpin

        interval: Theme.pageSpin + 200
        onTriggered: root.pending?.execute()
    }

    Process {
        id: copier
    }

    // Remembered between sessions, so the launcher learns your habits
    FileView {
        id: memory

        path: Quickshell.statePath("apps.json")
        onLoaded: {
            try {
                root.uses = JSON.parse(text());
            } catch (error) {
                root.uses = {};
            }
        }
    }

    // The emoji and their names, English and French, from Unicode and CLDR
    FileView {
        id: emojiFile

        path: Quickshell.shellPath("assets/emoji.tsv")
        blockLoading: true
    }
}
