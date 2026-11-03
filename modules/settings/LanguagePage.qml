import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Which language the shell speaks, and which ones the keyboard types.
ColumnLayout {
    id: root

    // The keyboard's languages as Settings sees them: yours once picked, Hyprland's until then
    readonly property var chosen: Config.keyboardLayouts.length ? Config.keyboardLayouts : Keyboard.layouts
    property string search: ""
    readonly property var found: {
        const wanted = search.trim().toLowerCase();
        if (wanted.length < 2)
            return [];
        return Keyboard.known.filter(layout => !chosen.includes(layout.code) && (layout.name.toLowerCase().includes(wanted) || layout.code === wanted)).slice(0, 6);
    }

    function move(code, step) {
        const list = chosen.slice(), at = list.indexOf(code), to = at + step;
        if (to < 0 || to >= list.length)
            return;
        list.splice(at, 1);
        list.splice(to, 0, code);
        Keyboard.choose(list);
    }

    spacing: 18

    Text {
        text: Lang.t("Langue")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 20
    }

    SettingChoice {
        label: Lang.t("Langue du shell")
        hint: Lang.t("Automatique suit la langue de ton système.")
        options: [{ id: "auto", label: Lang.t("Automatique") }].concat(Lang.languages)
        current: Config.language
        onPicked: id => Config.language = id
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        text: Lang.t("Ta langue n'y est pas ? Copie i18n/en.json, traduis chaque phrase et ajoute-la à Lang.languages : ETEA la parlera.")
        wrapMode: Text.Wrap
        color: Qt.alpha(Theme.text, 0.6)
        font.family: Theme.font
        font.pixelSize: 12
    }

    SettingSection {
        text: Lang.t("Clavier")
    }

    Text {
        Layout.fillWidth: true
        text: Lang.t("Les langues que tape ton clavier, la première au démarrage. Dans la barre, un clic passe à la suivante.")
        wrapMode: Text.Wrap
        color: Qt.alpha(Theme.text, 0.6)
        font.family: Theme.font
        font.pixelSize: 12
    }

    Repeater {
        model: root.chosen

        SettingRow {
            id: layout

            required property string modelData
            required property int index

            label: Keyboard.nameOf(modelData)
            hint: modelData.toUpperCase()

            Row {
                spacing: 8

                SettingButton {
                    visible: layout.index > 0
                    label: "↑"
                    quiet: true
                    onPicked: root.move(layout.modelData, -1)
                }

                SettingButton {
                    visible: root.chosen.length > 1
                    label: Lang.t("Retirer")
                    quiet: true
                    onPicked: Keyboard.choose(root.chosen.filter(code => code !== layout.modelData))
                }
            }
        }
    }

    SettingRow {
        label: Lang.t("Ajouter une langue")

        Rectangle {
            width: 260
            height: 36
            radius: 0
            color: Qt.alpha(Theme.windowLit, field.activeFocus ? 0.14 : 0.08)

            TextInput {
                id: field

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                clip: true
                onTextChanged: root.search = text
            }

            Text {
                visible: field.text === ""
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                text: Lang.t("Français, German, es…")
                color: Qt.alpha(Theme.text, 0.4)
                font.family: Theme.font
                font.pixelSize: 13
            }
        }
    }

    Repeater {
        model: root.found

        SettingRow {
            required property var modelData

            label: modelData.name
            hint: modelData.code.toUpperCase()

            SettingButton {
                label: Lang.t("Ajouter")
                quiet: true
                onPicked: {
                    Keyboard.choose(root.chosen.concat([modelData.code]));
                    field.text = "";
                }
            }
        }
    }
}
