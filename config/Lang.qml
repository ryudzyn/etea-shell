pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every word the shell shows goes through Lang.t(). The code is written in French, and
// each other language is one file in i18n/, mapping a French sentence to its translation.
// Anything missing from a file simply stays in French, so a translation can grow bit by bit.
Singleton {
    id: root

    readonly property var languages: [{ id: "uk", label: "Українська" }, { id: "fr", label: "Français" }, { id: "en", label: "English" }]
    readonly property string system: Qt.locale().name.split("_")[0]
    readonly property string code: Config.language !== "auto" ? Config.language : languages.some(language => language.id === system) ? system : "en"
    readonly property string locale: ({ uk: "uk_UA", fr: "fr_FR", en: "en_US" })[code] ?? code
    property var words: ({})

    // {0}, {1}… stand for the values passed after the sentence
    function t(text, ...values) {
        let out = code === "fr" ? text : words[text] ?? text;
        values.forEach((value, i) => out = out.replace(`{${i}}`, value));
        return out;
    }

    FileView {
        path: root.code === "fr" ? "" : Quickshell.shellPath(`i18n/${root.code}.json`)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.words = JSON.parse(text());
            } catch (error) {
                console.warn("ETEA: can't read the translation", path, error);
            }
        }
        onLoadFailed: root.words = {}
    }
}
