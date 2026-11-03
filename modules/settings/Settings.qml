import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.bar
import qs.modules.stage
import qs.services

// The settings page. It's a real window, so it's born from a star and gets its frame
// like any other. Sections are a constellation down the side, every change applies live.
Scope {
    FloatingWindow {
        id: window

        property int section: 0

        readonly property var sections: [
            { label: Lang.t("Monde"), page: "WorldPage.qml" },
            { label: Lang.t("Bureau"), page: "DesktopPage.qml" },
            { label: Lang.t("Barre"), page: "BarPage.qml" },
            { label: Lang.t("Fenêtres"), page: "WindowsPage.qml" },
            { label: Lang.t("Mouvement"), page: "MotionPage.qml" },
            { label: Lang.t("Système"), page: "SystemPage.qml" },
            { label: Lang.t("Verrouillage"), page: "LockPage.qml" },
            { label: Lang.t("Langue"), page: "LanguagePage.qml" },
            { label: Lang.t("À propos"), page: "AboutPage.qml" }
        ]

        title: "Réglages ETEA"
        visible: Menus.settingsOpen
        implicitWidth: 1040
        implicitHeight: 700
        color: Theme.cardDeep

        onVisibleChanged: {
            if (!visible)
                Menus.settingsOpen = false;
        }

        HandCard {
            anchors.fill: parent
            anchors.margins: -8
            seed: "settings"
            radius: 0
            ink: 0
            rise: 0.05
            tint: Theme.windowLit
            alive: window.visible
        }

        Item {
            id: side

            x: 30
            y: 36
            width: 190
            height: parent.height - 60

            Text {
                text: Lang.t("Réglages")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 26
                font.weight: Font.Light
            }

            // The thread running through the sections
            Rectangle {
                x: 9
                y: 76
                width: 1
                height: (window.sections.length - 1) * 54
                color: Qt.alpha(Theme.link, 0.35)
            }

            Repeater {
                model: window.sections

                Item {
                    id: entry

                    required property var modelData
                    required property int index

                    readonly property bool active: index === window.section

                    y: 58 + index * 54
                    width: side.width
                    height: 36

                    Star {
                        x: 10 - size
                        y: parent.height / 2 - size
                        size: entry.active ? 9 : 5
                        lit: entry.active
                        animated: false

                        Behavior on size {
                            NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.expressive }
                        }
                    }

                    Text {
                        x: 32
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.label
                        color: entry.active ? Theme.text : Qt.alpha(Theme.text, 0.65)
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: entry.active ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: window.section = entry.index
                    }
                }
            }
        }

        // The clipping edge sits a little outside the content, so the stars and ink lines
        // around the cards have room and don't get sliced off
        Flickable {
            id: scroller

            readonly property int room: 18

            x: side.x + side.width + 30 - room
            y: 36 - room
            width: parent.width - x - 40 + room
            height: parent.height - 60 + room * 2
            contentHeight: page.height + 20 + room * 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: page

                x: scroller.room
                y: scroller.room
                width: parent.width - scroller.room * 2
                source: window.sections[window.section].page
            }
        }
    }
}
