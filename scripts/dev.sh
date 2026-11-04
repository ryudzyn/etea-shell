#!/usr/bin/env bash
# Runs ETEA from this folder while you work on it. Saving a file reloads it live.
#   scripts/dev.sh start      (re)starts ETEA
#   scripts/dev.sh stop       stops it
#   scripts/dev.sh logs       follows what ETEA has to say
#   scripts/dev.sh shortcuts  takes the shell's shortcuts back after a Hyprland reload
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Finds ETEA by what it's running rather than by name: after a crash, Quickshell
# restarts itself as plain "quickshell" and a name search would walk right past it
etea_pids() {
    qs list --all --json 2>/dev/null | ROOT="$ROOT" python3 -c '
import json, os, sys
root = os.environ["ROOT"] + "/shell.qml"
try:
    instances = json.load(sys.stdin)
except ValueError:
    instances = []  # qs prints plain text when nothing is running
for instance in instances:
    if instance["config_path"] == root:
        print(instance["pid"])
'
}

# Two bars would each reserve their own space, so make sure every instance is gone
stop_etea() {
    local pids
    pids="$(etea_pids)"
    [[ -z "$pids" ]] && return 0
    kill $pids 2>/dev/null || true
    for _ in {1..20}; do
        [[ -z "$(etea_pids)" ]] && return 0
        sleep 0.1
    done
    kill -9 $(etea_pids) 2>/dev/null || true
}

# ETEA takes over the page shortcuts for this session and turns off Hyprland's
# own page animation. Nothing is written to your config, a reload undoes it all.
take_pages() {
    hyprctl eval '
        local keys = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
        local pad = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
        for i = 1, 10 do
            hl.unbind("SUPER + " .. (i % 10))
            hl.unbind("SUPER + code:" .. keys[i])
            hl.unbind("SUPER + code:" .. pad[i])
            hl.bind("SUPER + code:" .. keys[i], hl.dsp.global("etea:page" .. i))
            hl.bind("SUPER + code:" .. pad[i], hl.dsp.global("etea:page" .. i))
        end
        hl.unbind("CTRL + SUPER + Right")
        hl.unbind("CTRL + SUPER + Left")
        hl.bind("CTRL + SUPER + Right", hl.dsp.global("etea:pageNext"), { description = "Shell: Next page" })
        hl.bind("CTRL + SUPER + Left", hl.dsp.global("etea:pagePrevious"), { description = "Shell: Previous page" })
        -- Super alone opens nothing here: the launcher is on Super + D in the Hyprland config
        hl.unbind("SUPER + SUPER_L")
        hl.unbind("SUPER + SUPER_R")
        hl.unbind("SUPER + A")
        hl.bind("SUPER + A", hl.dsp.global("etea:panelLeft"), { description = "Shell: Logbook" })
        hl.unbind("SUPER + N")
        hl.bind("SUPER + N", hl.dsp.global("etea:panelRight"), { description = "Shell: Control centre" })
        hl.unbind("SUPER + V")
        hl.bind("SUPER + V", hl.dsp.global("etea:clipboard"), { description = "Shell: Clipboard history" })
        hl.unbind("SUPER + SHIFT + S")
        hl.bind("SUPER + SHIFT + S", hl.dsp.global("etea:capture"), { description = "Shell: Capture (Tab for video)" })
        hl.unbind("SUPER + Comma")
        hl.bind("SUPER + Comma", hl.dsp.global("etea:settings"), { description = "Shell: Settings" })
        hl.unbind("SUPER + Slash")
        hl.bind("SUPER + Slash", hl.dsp.global("etea:cheatsheet"), { description = "Shell: Shortcuts" })
        hl.unbind("SUPER + SHIFT + Tab")
        hl.bind("SUPER + SHIFT + Tab", hl.dsp.global("etea:orbitDown"), { description = "Shell: Come back down" })
        hl.unbind("SUPER + Tab")
        hl.bind("SUPER + Tab", hl.dsp.global("etea:orbit"), { description = "Shell: Orbit, then the planets" })
        hl.unbind("SUPER + Q")
        hl.bind("SUPER + Q", hl.dsp.global("etea:closeWindow"), { description = "Shell: Close the window" })
        -- Super + wheel turns the page, or resizes the widget under the pointer
        hl.unbind("SUPER + mouse_up")
        hl.unbind("SUPER + mouse_down")
        hl.bind("SUPER + mouse_up", hl.dsp.global("etea:wheelUp"), { description = "Shell: Next page, or grow a widget" })
        hl.bind("SUPER + mouse_down", hl.dsp.global("etea:wheelDown"), { description = "Shell: Previous page, or shrink a widget" })
    ' | grep -v '^ok$' || true

    # Up and down go to the orbit. Sideways belongs to the page transition, which ETEA
    # sets up itself (modules/stage/Illumination.qml) since it depends on the settings.
    # Hyprland complains when removing a gesture that isn't there, which is fine here.
    for direction in up down; do
        hyprctl eval "if ETEA_ORBIT_GESTURES then hl.gesture({ fingers = 4, direction = \"$direction\", action = \"unset\" }) end" >/dev/null 2>&1 || true
    done
    hyprctl eval '
        ETEA_ORBIT_GESTURES = true
        hl.gesture({ fingers = 4, direction = "up", action = function()
            hl.dispatch(hl.dsp.global("etea:orbit"))
        end })
        hl.gesture({ fingers = 4, direction = "down", action = function()
            hl.dispatch(hl.dsp.global("etea:orbitDown"))
        end })
    ' | grep -v '^ok$' || true
}

case "${1:-}" in
start | restart)
    stop_etea
    # ETEA shows notifications itself, and only one program can
    pkill -x mako 2>/dev/null || true
    qs -p "$ROOT" -d
    take_pages
    ;;
stop)
    stop_etea
    ;;
shortcuts)
    # The shell calls this itself after a Hyprland reload, which wipes them
    take_pages
    ;;
logs)
    qs log -p "$ROOT" -f
    ;;
*)
    echo "Usage: $0 {start|restart|stop|shortcuts|logs}" >&2
    exit 1
    ;;
esac
