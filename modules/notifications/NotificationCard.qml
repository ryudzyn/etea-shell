import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.modules.bar
import qs.modules.stage
import qs.services

// One message from far away. It arrives as a comet and opens where it lands, and a star
// creeping along its bottom edge shows how long it has left. Point at it and time stops.
Item {
    id: root

    required property var entry
    property bool inJournal: false

    // After a restart only the copy is left: same words, no buttons
    readonly property var notification: entry.notification ?? entry.saved
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property string picture: {
        if (notification?.image)
            return notification.image;
        if (notification?.appIcon)
            return notification.appIcon.includes("/") ? `file://${notification.appIcon}` : Quickshell.iconPath(notification.appIcon, true);
        return "";
    }

    property real opened: inJournal ? 1 : 0
    property real life: 1
    property bool counting: false

    width: Theme.notifWidth
    height: card.height

    function when() {
        const minutes = Math.floor((Date.now() - entry.time.getTime()) / 60000);
        if (minutes < 1)
            return Lang.t("à l'instant");
        if (minutes < 60)
            return Lang.t("il y a {0} min", minutes);
        return Config.time(entry.time);
    }

    Component.onCompleted: {
        if (!inJournal)
            comet.start();
    }

    ContentTint {
        id: colour

        image: root.notification?.image ?? ""
        forced: root.critical ? "#f0705f" : ""
        name: root.notification?.appName ?? "etea"
    }

    SequentialAnimation {
        id: comet

        ParallelAnimation {
            NumberAnimation {
                target: head
                property: "x"
                from: Theme.notifWidth + 220
                to: 30
                duration: Theme.notifComet
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: head
                property: "y"
                from: -46
                to: 40
                duration: Theme.notifComet
                easing.type: Easing.OutCubic
            }
        }
        NumberAnimation {
            target: root
            property: "opened"
            from: 0
            to: 1
            duration: Theme.notifOpen
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                if (!root.critical)
                    root.counting = true;
            }
        }
    }

    NumberAnimation {
        id: countdown

        target: root
        property: "life"
        from: 1
        to: 0
        duration: root.notification?.expireTimeout > 0 ? root.notification.expireTimeout : Theme.notifLife
        running: root.counting
        paused: root.counting && sky.hovered
        onFinished: Notifs.hide(root.entry)
    }

    Item {
        id: card

        width: parent.width
        height: Math.max(content.implicitHeight + 50, 112)

        // Opens through the same star as a window
        layer.enabled: root.opened < 1
        layer.effect: StarMask {
            center: Qt.point(30, 40)
            reach: fullReach * root.opened
            shine: (1 - root.opened) * 0.9
            tint: colour.color
        }

        HandCard {
            id: sky

            anchors.fill: parent
            seed: `${root.notification?.id ?? 0}${root.notification?.summary ?? ""}`
            tint: colour.color
            ink: root.critical ? 1 : 0.72
            rise: root.critical ? 0.2 : 0.11
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => mouse.button === Qt.RightButton || root.inJournal ? Notifs.dismiss(root.entry) : Notifs.hide(root.entry)
        }

        RowLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 14

            // The app's picture, with a tiny star going round it like a moon
            Item {
                visible: root.picture !== ""
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58

                ClippingRectangle {
                    anchors.centerIn: parent
                    width: 48
                    height: 48
                    radius: 0
                    color: Qt.alpha(colour.color, 0.14)

                    Image {
                        anchors.fill: parent
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        source: root.picture
                    }
                }

                Item {
                    id: moon

                    anchors.fill: parent

                    Star {
                        x: parent.width / 2 - size
                        y: -size + 2
                        size: 5
                        lit: true
                        animated: false
                    }

                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 5200
                        loops: Animation.Infinite
                        running: sky.alive
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: root.notification?.appName ?? ""
                        elide: Text.ElideRight
                        color: colour.color
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.letterSpacing: 0.4
                    }

                    Text {
                        text: root.when()
                        color: Qt.alpha(Theme.text, 0.55)
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.notification?.summary ?? ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 16
                }

                Text {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: root.notification?.body ?? ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    color: Qt.alpha(Theme.text, 0.78)
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Row {
                    visible: (root.notification?.actions.length ?? 0) > 0
                    Layout.topMargin: 6
                    spacing: 16

                    Repeater {
                        model: root.notification?.actions ?? []

                        Text {
                            required property var modelData

                            text: modelData.text
                            color: colour.color
                            font.family: Theme.font
                            font.pixelSize: 13

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onPressed: parent.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }

        // The time left, a star walking the bottom edge
        Star {
            visible: !root.inJournal && !root.critical && root.opened === 1
            x: parent.width * root.life - size
            y: parent.height - size
            size: 7
            lit: true
            animated: false
        }
    }

    // The head of the comet, trailing light behind it
    Item {
        id: head

        visible: !root.inJournal && root.opened < 1
        opacity: 1 - root.opened

        Rectangle {
            y: -1
            width: 170
            height: 2
            rotation: -18
            transformOrigin: Item.Left
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(colour.color, 0.9) }
                GradientStop { position: 1; color: Qt.alpha(colour.color, 0) }
            }
        }

        Star {
            x: -size
            y: -size
            size: 15
            lit: true
            animated: false
        }
    }
}
