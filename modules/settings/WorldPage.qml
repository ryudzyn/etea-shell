import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar
import qs.services

// Тема фону: кожен стіл зі своєю планетою або один із шейдерів глибокого космосу.
ColumnLayout {
    id: root

    spacing: 18

    readonly property var choices: [{ id: "", name: "Планети", line: "Кожен стіл -- своя планета" }].concat(Planets.deep)

    Text {
        text: "Тема"
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 20
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: "Super + Shift + G -- те саме через меню. Super + G повертає камеру шейдера."
        color: Qt.alpha(Theme.text, 0.65)
        font.family: Theme.font
        font.pixelSize: 13
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
            model: root.choices

            Rectangle {
                id: choice

                required property var modelData
                readonly property bool picked: Config.deepSpace === modelData.id
                readonly property color tint: modelData.light ?? Theme.windowLit

                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: hand.containsMouse ? Qt.alpha(tint, 0.08) : "transparent"
                border.width: 1
                border.color: picked ? tint : Qt.alpha(Theme.text, 0.2)

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    spacing: 2

                    Text {
                        text: choice.modelData.name
                        color: choice.picked ? choice.tint : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 15
                    }

                    Text {
                        text: choice.picked ? "Зараз активна" : choice.modelData.line
                        color: Qt.alpha(Theme.text, 0.6)
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: hand
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.deepSpace = choice.modelData.id
                }
            }
        }
    }
}
