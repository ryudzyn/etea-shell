import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The window you're working in lights up, the others step back into the shade.
// Hyprland does the drawing, we just hand it the values from Theme.
Scope {
    id: root

    // Hyprland wants rgba(rrggbbaa), Qt gives us something else
    function hyprColor(color, alpha) {
        const hex = value => Math.round(value * 255).toString(16).padStart(2, "0");
        return `rgba(${hex(color.r)}${hex(color.g)}${hex(color.b)}${hex(alpha)})`;
    }

    // Config.glassApps as a Lua table: class name to opacity
    readonly property string glass: Config.glassApps.map(app => `["${app.class}"] = ${app.opacity ?? 0}`).join(", ")

    // Changing page: the planet turning under the fingers, or Hyprland's own slide
    readonly property string pages: Config.pageTransition === "slide" ? `
        hl.curve("eteaSlide", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
        hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "eteaSlide", style = "slide" })
        if ETEA_SIDE_GESTURE then pcall(hl.gesture, { fingers = 4, direction = "horizontal", action = "unset" }) end
        ETEA_SIDE_GESTURE = true
        hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
    ` : `
        hl.animation({ leaf = "workspaces", enabled = false })
        if ETEA_SIDE_GESTURE then pcall(hl.gesture, { fingers = 4, direction = "horizontal", action = "unset" }) end
        ETEA_SIDE_GESTURE = true
        -- The start of the swipe, every move and its end reach the shell as events
        hl.gesture({ fingers = 4, direction = "horizontal", action = {
            start = function()
                hl.dispatch(hl.dsp.event("etea:swipe,start"))
            end,
            update = function(e)
                hl.dispatch(hl.dsp.event("etea:swipe,move," .. (e.delta and e.delta.x or 0)))
            end,
            finish = function(e)
                hl.dispatch(hl.dsp.event("etea:swipe,end," .. tostring(e.cancelled == true)))
            end
        } })
    `

    readonly property string settings: `
        hl.config({
            general = {
                border_size = ${Theme.traceWidth},
                gaps_in = ${Theme.windowGapInner},
                gaps_out = ${Theme.windowGapOuter},
                col = {
                    active_border = "${hyprColor(Theme.windowLit, Theme.traceLine)}",
                    inactive_border = "${hyprColor(Theme.windowLit, Theme.windowRestBorder)}"
                }
            },
            decoration = {
                dim_inactive = true,
                dim_strength = ${Theme.windowDim},
                shadow = {
                    enabled = true,
                    range = ${Theme.windowGlowSize},
                    render_power = ${Theme.windowGlowPower},
                    offset = { 0, 0 },
                    color = "${hyprColor(Theme.windowLit, Theme.windowGlow)}",
                    color_inactive = "${hyprColor(Theme.windowRestShadow, Theme.windowRestShadowAlpha)}"
                }
            }
        })
        -- The stock rules switch shadows off on tiled windows, and the glow is a shadow
        hl.window_rule({ match = { float = 0 }, no_shadow = false })
        for _, window in ipairs(hl.get_windows()) do
            hl.dispatch(hl.dsp.window.set_prop({ prop = "no_shadow", value = "false", window = "address:" .. window.address }))
        end
        -- A slow, even curve: the usual ones do most of the change in the first few frames
        hl.curve("eteaFocus", { type = "bezier", points = { { 0.42, 0 }, { 0.58, 1 } } })
        -- ETEA plays closing windows itself. Apps that quit on their own still fade out quickly.
        hl.animation({ leaf = "windowsOut", enabled = false })
        hl.animation({ leaf = "windowsIn", enabled = false })

        -- Glass apps. The stock rules switch blur off on every window and a later rule can't
        -- turn it back on, but set_prop outranks rules. 0 means the app fades itself.
        ETEA_GLASS = { ${root.glass} }
        function ETEA_GLAZE()
            for _, window in ipairs(hl.get_windows()) do
                local opacity = ETEA_GLASS[window.class]
                if opacity then
                    local target = "address:" .. window.address
                    hl.dispatch(hl.dsp.window.set_prop({ prop = "no_blur", value = "false", window = target }))
                    if opacity > 0 then
                        hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity", value = tostring(opacity), window = target }))
                        hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity_inactive", value = tostring(math.max(0.1, opacity - 0.1)), window = target }))
                    end
                end
            end
        end
        ETEA_GLAZE()
        if not ETEA_GLAZING then
            ETEA_GLAZING = true
            hl.on("window.open", function() ETEA_GLAZE() end)
            -- Some apps only say who they are after the window is up
            hl.on("window.class", function() ETEA_GLAZE() end)
        end

        -- Always opaque, even unfocused: the text behind would bleed through the labels
        hl.window_rule({ match = { title = "Réglages ETEA" }, float = true, center = true, size = { 1040, 700 }, opacity = "1.0 override 1.0 override" })
        -- The side panels unfold through their own star, a layer fade on top would make them see-through
        hl.layer_rule({ match = { namespace = "^etea:panel-.*" }, no_anim = true })
        -- The capture overlay has to be gone at once, or it ends up in the picture
        hl.layer_rule({ match = { namespace = "^etea:capture$" }, no_anim = true })

        -- A new window waits a beat so ETEA can get the sky in front of it: this curve sits
        -- at zero almost the whole way. It all happens inside Hyprland, so a window can't
        -- get stuck hidden, even if ETEA crashes.
        hl.curve("eteaHold", { type = "bezier", points = { { 1, 0 }, { 1, 0 } } })
        hl.animation({ leaf = "fadeIn", enabled = true, speed = ${Theme.openCover / 100}, bezier = "eteaHold" })

        -- Hyprland tells ETEA a window is coming before it appears, so the screen can be
        -- frozen in time. Neighbours start moving slowly, just long enough for that photo.
        hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
        hl.curve("eteaSlowStart", { type = "bezier", points = { { 0.7, 0 }, { 0.3, 1 } } })
        ETEA_MAKE_ROOM = ${Theme.openMakeRoom / 100}
        if not ETEA_BIRTHS then
            ETEA_BIRTHS = true
            hl.on("window.open_early", function()
                hl.dispatch(hl.dsp.global("etea:windowOpening"))
                hl.animation({ leaf = "windowsMove", enabled = true, speed = ETEA_MAKE_ROOM, bezier = "eteaSlowStart", style = "slide" })
                hl.timer(function()
                    hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "${Theme.windowMoveCurve}", style = "slide" })
                end, { timeout = ETEA_MAKE_ROOM * 100, type = "oneshot" })
            end)
        end
        hl.animation({ leaf = "border", enabled = true, speed = ${Theme.windowFocusSpeed}, bezier = "eteaFocus" })
        hl.animation({ leaf = "fadeSwitch", enabled = true, speed = ${Theme.windowFocusSpeed}, bezier = "eteaFocus" })
        hl.animation({ leaf = "fadeDim", enabled = true, speed = ${Theme.windowFocusSpeed}, bezier = "eteaFocus" })
        hl.animation({ leaf = "fadeShadow", enabled = true, speed = ${Theme.windowFocusSpeed}, bezier = "eteaFocus" })
        ${root.pages}
    `

    onSettingsChanged: reapply.restart()


    // Sliders and themes change this quickly, Hyprland only needs the final answer
    Timer {
        id: reapply

        interval: 120
        onTriggered: apply.running = true
    }

    Process {
        id: apply

        command: ["hyprctl", "eval", root.settings]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "ok")
                    console.warn("ETEA illumination:", text.trim());
            }
        }
    }

    // The shortcuts ETEA takes over, from scripts/dev.sh
    Process {
        id: shortcuts

        command: ["bash", Quickshell.shellPath("scripts/dev.sh"), "shortcuts"]
    }

    // A Hyprland reload wipes everything we set, shortcuts included, so put it right back
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                apply.running = true;
                shortcuts.running = true;
            }
        }
    }

    // Started straight from Hyprland, the shell takes its shortcuts itself
    Component.onCompleted: {
        apply.running = true;
        shortcuts.running = true;
    }
}
