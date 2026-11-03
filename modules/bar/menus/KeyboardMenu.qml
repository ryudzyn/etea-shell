import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// The keyboard's languages, to jump straight to one. Which ones are here is set in Settings.
ColumnLayout {
    id: root

    readonly property color cardTint: Theme.windowLit
    readonly property real cardRise: 0.06

    spacing: 4
    width: 280

    MenuTitle {
        Layout.bottomMargin: 4
        text: Lang.t("Clavier")
    }

    Repeater {
        model: Keyboard.layouts

        MenuRow {
            required property string modelData
            required property int index

            Layout.fillWidth: true
            label: Keyboard.nameOf(modelData)
            detail: modelData.toUpperCase()
            active: index === Keyboard.current
            onPicked: Keyboard.select(index)
        }
    }

    MenuRow {
        Layout.fillWidth: true
        Layout.topMargin: 4
        label: Lang.t("Choisir les langues…")
        onPicked: {
            Menus.close();
            Menus.settingsOpen = true;
        }
    }
}
