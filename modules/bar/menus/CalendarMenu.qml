import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.bar
import qs.services

// The month at a glance. Today is the one with a star on it.
ColumnLayout {
    id: root

    property date shown: new Date()
    readonly property var locale: Qt.locale(Config.locale)

    function shift(months) {
        shown = new Date(shown.getFullYear(), shown.getMonth() + months, 1);
    }

    readonly property color cardTint: Theme.windowLit
    readonly property real cardRise: 0.07

    spacing: 8
    width: 300

    RowLayout {
        Layout.fillWidth: true

        Icon {
            name: "caret-left"
            size: 20

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onPressed: root.shift(-1)
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.locale.toString(root.shown, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
        }

        Icon {
            name: "caret-right"
            size: 20

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onPressed: root.shift(1)
            }
        }
    }

    // Tonight's moon, drawn from the real date
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 2
        spacing: 10

        MoonDisc {
            id: moon

            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
        }

        Text {
            text: moon.phaseName
            color: Qt.alpha(Theme.text, 0.75)
            font.family: Theme.font
            font.pixelSize: 13
        }
    }

    MonthGrid {
        Layout.fillWidth: true
        month: root.shown
        heading: Menus.tint
    }
}
