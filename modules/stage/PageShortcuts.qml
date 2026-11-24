import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services

// The keyboard's way in, wired up by scripts/dev.sh. These can't live inside the
// Planet singleton: it gets torn down after Wayland is gone and that crashes the shell.
Scope {
    // Super + a number goes to that page of the group you're in, like on end4
    Instantiator {
        model: 10

        GlobalShortcut {
            required property int index

            appid: "etea"
            name: "page" + (index + 1)
            onPressed: {
                if (index < Config.pages)
                    Planet.request(Planet.groupStart + index);
            }
        }
    }

    GlobalShortcut {
        appid: "etea"
        name: "orbit"
        onPressed: Planet.toggleOrbit()
    }

    GlobalShortcut {
        appid: "etea"
        name: "orbitDown"
        onPressed: Planet.goDown()
    }

    GlobalShortcut {
        appid: "etea"
        name: "settings"
        onPressed: Menus.settingsOpen = !Menus.settingsOpen
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            Menus.settingsOpen = !Menus.settingsOpen;
        }

        // Super+Shift+G: вибір шпалери -- розділ "Світ"
        function world(): void {
            Menus.settingsSection = 0;
            Menus.settingsOpen = true;
        }
    }

    IpcHandler {
        target: "planet"

        function orbit(): void {
            Planet.toggleOrbit();
        }

        function down(): void {
            Planet.goDown();
        }

        // Where the planet is up to, handy when something looks wrong
        function state(): string {
            return `phase ${Planet.phase}, page ${Planet.current}, group from ${Planet.groupStart}, resting ${Planet.resting.toFixed(2)}, altitude ${Planet.altitude}`;
        }

        function land(page: int): void {
            Planet.leaveOrbit(page);
        }
    }

    GlobalShortcut {
        appid: "etea"
        name: "pageNext"
        onPressed: Planet.requestNext(1)
    }

    GlobalShortcut {
        appid: "etea"
        name: "pagePrevious"
        onPressed: Planet.requestNext(-1)
    }

    // Super + wheel: over a widget it changes its size, anywhere else it turns the page
    GlobalShortcut {
        appid: "etea"
        name: "wheelUp"
        onPressed: Desk.hovered ? Desk.grow(Desk.hovered, 1) : Planet.requestNext(1)
    }

    GlobalShortcut {
        appid: "etea"
        name: "wheelDown"
        onPressed: Desk.hovered ? Desk.grow(Desk.hovered, -1) : Planet.requestNext(-1)
    }
}
