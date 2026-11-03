import QtQuick
import qs.config
import qs.modules.bar

// One option out of a few. A star marks the one in use and slides over to the next.
SettingRow {
    id: root

    property var options: [] // { id, label }
    property string current: ""

    signal picked(string id)

    Row {
        spacing: 6

        Repeater {
            model: root.options

            Item {
                id: option

                required property var modelData

                readonly property bool active: modelData.id === root.current

                width: name.implicitWidth + 30
                height: 34

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: Theme.windowLit
                    opacity: option.active ? 0.2 : pointer.containsMouse ? 0.09 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.fast }
                    }
                }

                Text {
                    id: name

                    anchors.centerIn: parent
                    text: option.modelData.label
                    color: option.active ? Theme.text : Qt.alpha(Theme.text, 0.7)
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                StarRipple {
                    id: ripple
                }

                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => {
                        ripple.burst(mouse.x, mouse.y);
                        root.picked(option.modelData.id);
                    }
                }
            }
        }
    }
}
