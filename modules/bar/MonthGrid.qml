import QtQuick
import QtQuick.Layouts
import qs.config

// A month laid out in weeks, starting on the day the language starts them.
// Today is the one with a star on it.
GridLayout {
    id: root

    property date month: new Date()
    property color ink: Theme.text
    property color heading: ink
    property real unit: 13 // the size of a day's number, everything else follows

    property date today: new Date() // widgets that stay up for days keep this current
    readonly property var locale: Qt.locale(Config.locale)
    readonly property int firstDay: locale.firstDayOfWeek
    readonly property var days: {
        const first = new Date(month.getFullYear(), month.getMonth(), 1);
        const offset = (first.getDay() - firstDay + 7) % 7;
        const cells = [];
        for (let i = 0; i < 42; i++)
            cells.push(new Date(month.getFullYear(), month.getMonth(), i - offset + 1));
        return cells;
    }

    columns: 7
    rowSpacing: 0
    columnSpacing: 0

    Repeater {
        model: 7

        Text {
            required property int index

            Layout.fillWidth: true
            Layout.preferredHeight: root.unit * 2.1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.locale.dayName((root.firstDay + index) % 7, Locale.ShortFormat).replace(/\.$/, "")
            color: root.heading
            font.family: Theme.font
            font.pixelSize: root.unit * 0.77
        }
    }

    Repeater {
        model: root.days

        Item {
            id: cell

            required property var modelData

            readonly property bool isToday: modelData.toDateString() === root.today.toDateString()

            Layout.fillWidth: true
            Layout.preferredHeight: root.unit * 2.75

            Rectangle {
                visible: cell.isToday
                anchors.centerIn: parent
                width: root.unit * 2.2
                height: width
                color: Theme.windowLit
            }

            Text {
                anchors.centerIn: parent
                text: cell.modelData.getDate()
                color: cell.isToday ? "#07090c" : Qt.alpha(root.ink, cell.modelData.getMonth() === root.month.getMonth() ? 0.9 : 0.3)
                font.family: Theme.font
                font.pixelSize: root.unit
            }
        }
    }
}
