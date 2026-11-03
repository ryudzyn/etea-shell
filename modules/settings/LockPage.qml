import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.modules.bar
import qs.services

// The lock screen: who draws it, what greets you before you type, and whether a finger
// is enough. The starry sky comes after, always.
ColumnLayout {
    id: root

    spacing: 18

    Text {
        text: Lang.t("Verrouillage")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 20
    }

    SettingChoice {
        label: Lang.t("Verrouiller avec")
        hint: Lang.t("Super + L, le menu de session, la mise en veille et la fermeture du capot.")
        options: [{ id: "etea", label: "ETEA" }, { id: "hyprlock", label: "hyprlock" }]
        current: Config.lockWith
        onPicked: id => Config.lockWith = id
    }

    SettingSwitch {
        visible: Config.lockWith === "etea"
        label: Lang.t("Empreinte digitale")
        hint: Lang.t("Pose ton doigt sur le lecteur à tout moment, le mot de passe marche toujours.")
        on: Config.lockFingerprint
        onToggled: Config.lockFingerprint = !Config.lockFingerprint
    }

    SettingChoice {
        visible: Config.lockWith === "etea"
        label: Lang.t("Premier écran")
        hint: Lang.t("Ce que tu vois avant de taper. Le ciel étoilé vient ensuite.")
        options: [{ id: "world", label: Lang.t("Ton monde") }, { id: "image", label: Lang.t("Une image") }]
        current: Config.lockImage ? "image" : "world"
        onPicked: id => {
            if (id === "world")
                Config.lockImage = "";
            else if (!Config.lockImage)
                picker.running = true;
        }
    }

    // The picture, framed like a little window onto the lock
    Item {
        visible: Config.lockImage !== ""
        Layout.fillWidth: true
        Layout.preferredHeight: 190

        HandCard {
            anchors.fill: photo
            anchors.margins: -6
            seed: "lock-image"
            rise: 0.06
        }

        Image {
            id: photo

            width: 320
            height: 180
            anchors.verticalCenter: parent.verticalCenter
            source: Config.lockImage ? "file://" + Config.lockImage : ""
            sourceSize.width: 640
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: corners
            }
        }

        Rectangle {
            id: corners

            width: photo.width
            height: photo.height
            radius: 0
            visible: false
            layer.enabled: true
        }

        Column {
            anchors.left: photo.right
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            SettingButton {
                label: Lang.t("Changer d'image")
                onPicked: picker.running = true
            }

            Text {
                width: 260
                text: Config.lockImage.split("/").pop()
                elide: Text.ElideMiddle
                color: Qt.alpha(Theme.text, 0.6)
                font.family: Theme.font
                font.pixelSize: 12
            }
        }
    }

    SettingRow {
        label: Lang.t("Essayer")
        hint: Lang.t("Ouvre l'écran sans rien verrouiller. Échap pour en sortir.")

        SettingButton {
            label: Lang.t("Aperçu")
            onPicked: Menus.lockPreview = true
        }
    }

    Process {
        id: picker

        command: ["sh", "-c", 'if command -v kdialog >/dev/null; then kdialog --title "$1" --getopenfilename "$HOME" "*.png *.jpg *.jpeg *.webp"; else zenity --file-selection --title "$1"; fi', "sh", Lang.t("Une image pour l'écran de verrouillage")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    Config.lockImage = text.trim();
            }
        }
    }
}
