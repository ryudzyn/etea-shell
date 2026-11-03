import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.config
import qs.services

// Signals from far away. They land in the top right corner, and stay in the
// journal until you clear them.
Scope {
    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: notification => {
            notification.tracked = true;
            Notifs.add(notification);
        }
    }

    IpcHandler {
        target: "notifications"

        function journal(): void {
            Menus.togglePanel("right");
        }

        function clear(): void {
            Notifs.clear();
        }

        function clearApp(app: string): void {
            Notifs.clear(app);
        }

        function quiet(on: bool): void {
            Notifs.quiet = on;
        }
    }

    PanelWindow {
        id: panel

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: Notifs.popups.length > 0 && !Menus.rightOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Theme.notifWidth + 40
        implicitHeight: screen.height - Theme.barReserve
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "etea:notifications"
        margins.top: Theme.barOnTop ? Theme.barReserve + 6 : 14

        anchors {
            top: true
            right: true
        }

        // Only the cards catch the mouse, the rest of the column stays usable
        mask: Region {
            Region { item: stack }
        }

        Column {
            id: stack

            x: 20
            y: 10
            spacing: 16

            Repeater {
                model: Notifs.popups

                NotificationCard {
                    required property var modelData

                    entry: modelData
                }
            }
        }
    }
}
