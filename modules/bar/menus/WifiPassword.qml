import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.services

// A password for a new network. It goes to nmcli over stdin rather than as an
// argument, so it never shows up in the list of running processes.
ColumnLayout {
    id: root

    required property string network

    signal finished()

    property bool failed: false

    function connect() {
        if (!field.text || join.running)
            return;
        failed = false;
        join.running = true;
    }

    spacing: 6

    Component.onCompleted: field.forceActiveFocus()

    Process {
        id: join

        command: ["nmcli", "--ask", "device", "wifi", "connect", root.network]
        stdinEnabled: true
        onStarted: {
            write(field.text + "\n");
            stdinEnabled = false;
        }
        onExited: code => {
            stdinEnabled = true;
            if (code === 0)
                root.finished();
            else
                root.failed = true;
        }
    }

    Text {
        text: root.failed ? Lang.t("Mot de passe refusé.") : join.running ? Lang.t("Connexion à {0}…", root.network) : Lang.t("Mot de passe pour {0}", root.network)
        color: root.failed ? "#f0947c" : Qt.alpha(Theme.text, 0.75)
        font.family: Theme.font
        font.pixelSize: 12
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 0
        color: Qt.alpha(Menus.tint, 0.12)
        border.width: 1
        border.color: Qt.alpha(Menus.tint, field.activeFocus ? 0.7 : 0.3)

        TextInput {
            id: field

            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            passwordCharacter: "✦"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            onAccepted: root.connect()
            Keys.onEscapePressed: root.finished()
        }
    }
}
