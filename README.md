> **Форк для Nebula OS**, гілка `nebula`. Оригінал: [SDcold/etea-shell](https://github.com/SDcold/etea-shell), GPL-3.0.
> Тут інша логіка (кожен стіл -- своя справжня планета, Super+Tab -- Сонячна система) і стиль (обсерваторія
> замість зірок і малюнка від руки). Текстури планет і шейдери теми "Глибокий космос" додаються під час
> збірки з [ryudzyn/nebula-config](https://github.com/ryudzyn/nebula-config), без них фон не запуститься.

# ETEA Shell

**Exit The Earth Atmosphere.** A desktop shell for [Hyprland](https://hyprland.org), built on
[Quickshell](https://quickshell.outfoxxed.me), for people who'd rather live on a planet than in a
grid of rectangles.

![The desktop on Vesper: a sky clock, karaoke lyrics, weather, music, calendar, the machine as a constellation and the music rising from the ground](doc/Screenshots/Desktop1.png)

Your workspaces are pages standing around a small planet, and switching pages turns it. New
windows are born from a star, closing ones fold back into one. Press `Super + Tab` and you rise
into orbit to see every page at once; press it again and you're among the planets, each one a
theme you can land on. The bar, the menus, the notifications and the lock screen all speak the
same language: hand-drawn ink lines, little four-pointed stars, and a sky that's always a bit
alive.

It started as "I want my desktop to feel like my drawings" and kind of got out of hand. 🌍✨

> ⚠️ This is a personal project that grew up in public. It runs every day on my laptop, but it's
> young: expect rough edges, the odd bug, and things that change their mind between commits.
> Issues and ideas are very welcome.

## What's inside

- **A planet of pages.** Workspaces in groups (8 by default), turned like a globe, with an
  orbit view to drag windows between them and a system view to pick your world.
- **Worlds, not themes.** Each planet brings its own sky, ground and colours. You can even make
  one from any picture.
- **A bar you arrange.** Islands, a band or bare sky, any module on any end, drag and drop in
  Settings. Pages as constellations or plain numbers.
- **Menus and panels** for sound (per-app volume, output and microphone), Wi-Fi and VPN,
  Bluetooth (with pairing), power, calendar and moon, music, keyboard languages, and a control
  centre with quick tiles and a notification journal grouped by app.
- **Desktop widgets** written straight on the sky or set in porthole cards: clock, system,
  music, weather, calendar, tasks, a photo frame, and karaoke lyrics that light up as the song
  goes. `Super + drag` moves them, `Super + wheel` resizes them, right click for options.
- **A launcher shaped like a sky map.** Apps by constellation, your favourites brightest. It also
  does maths (`sqrt(2)*pi`), commands (`>`), emoji (`:heart`, `:cœur`) and web searches (`?`).
- **Everyday tools:** clipboard history with image previews, region / window / full-screen
  capture, screen recording with or without sound, colour picker, night light, stay-awake, a
  polkit agent, battery alerts, OSDs.
- **A lock screen with a story.** A woman reaches for the stars as you type, her hand hiding each
  new one. It locks on idle and before sleep, and your fingerprint works too.
- **Shortcut cheatsheet** on `Super + /`, built from your own Hyprland binds.
- **French and English**, and adding a language is one JSON file.

| | |
|---|---|
| ![The same desktop on Néré, the ocean world](doc/Screenshots/Desktop2.png) | ![And on Aster, the evening that never ends](doc/Screenshots/Desktop3.png) |
| Néré, the ocean world | Aster, the evening that never ends |
| ![Orbit: every page standing around the planet](doc/Screenshots/Orbit.png) | ![The launcher: apps as constellations, your favourites brightest](doc/Screenshots/Launcher.png) |
| Orbit, every page at once | The launcher |
| ![Settings, where you choose your world or make one from a picture](doc/Screenshots/settings.png) | ![The session menu: lock, sleep, log out, restart, shut down](doc/Screenshots/quitpage.png) |
| Settings: choose your world | The session menu |
| ![The lock screen as your world: the time, the song and the fingerprint reader](doc/Screenshots/Loginscreen1.png) | ![The lock screen as a story: a woman reaching for the stars](doc/Screenshots/Loginscreen2.png) |
| The lock screen, as your world | …or as a story |

![Every shortcut on Super + /, ETEA's and your own](doc/Screenshots/shortcuts.png)

## How heavy is it?

It's built to stay out of the way when you're not looking at it: the sky and the widgets stop
moving behind your windows, and the big animations only exist while they play. On my laptop
(Intel Core i5-1335U, Intel Iris Xe graphics, 24 GB of RAM) the whole system uses **about
2.3 GB of RAM** with ETEA running on its own, and the frame rate stays steady through page turns,
orbit and window animations.

## Requirements

- **Hyprland 0.56 or newer, with the Lua config.** ETEA talks to Hyprland through `hyprctl eval`.
- **Quickshell 0.2.1 or newer**, with its Pipewire, Mpris, UPower, Bluetooth, Networking, Pam,
  Polkit and Notifications services (the AUR `quickshell-git` package has them all).
- PipeWire with `pactl`, NetworkManager, BlueZ, UPower and power-profiles-daemon.
- Command-line helpers: `cava`, `cliphist`, `wl-clipboard`, `grim`, `slurp`, `wf-recorder`, `hyprpicker`,
  `hyprsunset`, `brightnessctl`, `jq`, `curl`, `libnotify`, `xdg-user-dirs`, and `kdialog` or
  `zenity` for file pickers.
- Optional: `hypridle` and `hyprlock` (idle locking, and a fallback lock), `fprintd` for
  fingerprints.

The Poppins font and the icons ship with the shell, nothing to install there.

On Arch, something like:

```sh
yay -S quickshell-git cava cliphist wl-clipboard grim slurp wf-recorder hyprpicker hyprsunset \
    brightnessctl jq curl libnotify xdg-user-dirs zenity networkmanager bluez upower \
    power-profiles-daemon pipewire-pulse libpulse hypridle hyprlock fprintd
```

### On Fedora

> 🧪 **Not fully tested yet.** ETEA is developed on Arch (CachyOS). Nothing in it is tied to one
> distribution, but this route hasn't been walked end to end. If you try it, an issue saying what
> worked and what didn't would help a lot.

Fedora 45 ships Quickshell 0.2.1 in its own repos; on Fedora 41 to 43 it comes from the
[errornointernet/quickshell](https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell)
COPR. The tricky part is Hyprland: ETEA needs **0.56 or newer with the Lua config**, which is
usually newer than what Fedora carries, so it has to come from a COPR that follows Hyprland
closely (check which version it builds before enabling it). Package names can differ a little
from release to release; roughly:

```sh
sudo dnf copr enable errornointernet/quickshell   # Fedora 41 to 43 only
sudo dnf install quickshell cava cliphist wl-clipboard grim slurp wf-recorder hyprpicker \
    hyprsunset brightnessctl jq curl libnotify xdg-user-dirs zenity NetworkManager bluez \
    upower power-profiles-daemon pulseaudio-utils hypridle hyprlock fprintd fprintd-pam
```

## Installation

### The guided way

```sh
git clone https://github.com/SDcold/etea-shell.git ~/.config/etea-shell
~/.config/etea-shell/install.sh
```

The installer walks you through it and asks before every change: it checks your Hyprland,
installs what's missing (Arch and Fedora), points out other bars or notification daemons that
would get in the way, adds ETEA to your `hyprland.lua` (backing it up first), can set up locking
on idle and enrol a finger, then lifts off. Not sure? `install.sh --dry-run` shows everything it
would do without touching anything, and `install.sh --uninstall` takes ETEA back out.

### By hand

1. **Get it**, anywhere you like:

   ```sh
   git clone https://github.com/SDcold/etea-shell.git ~/.config/etea-shell
   ```

2. **Start it with Hyprland.** In your Lua config:

   ```lua
   hl.on("hyprland.start", function()
       hl.exec_cmd("qs -p ~/.config/etea-shell")
       hl.exec_cmd("wl-paste --watch cliphist store") -- the clipboard history needs this
   end)
   ```

   If another shell or notification daemon (mako, dunst, another Quickshell config…) is
   running, stop it first: only one program can show notifications, and two bars would fight
   over the top of your screen.

3. **Lock on idle with ETEA** (optional). In `~/.config/hypr/hypridle.conf`:

   ```ini
   general {
       lock_cmd = ~/.config/etea-shell/scripts/lock.sh
       before_sleep_cmd = loginctl lock-session
   }
   ```

   The script locks with ETEA, or with hyprlock if you picked it in Settings, and falls back to
   hyprlock if ETEA isn't answering. Never to nothing.

4. **Log out and back in**, or just run `qs -p ~/.config/etea-shell` to try it right away.

ETEA takes over a handful of shortcuts while it runs (pages, launcher, lock…). Nothing is
written to your Hyprland config: reload Hyprland and they're yours again, until the shell takes
them back a second later.

## First steps

| Keys | What happens |
|---|---|
| `Super` | The launcher |
| `Super + 1 … 0` | Go to a page |
| `Super + wheel`, `Ctrl + Super + ← →`, 4-finger swipe | Turn the planet |
| `Super + Tab` | Orbit, then the planets |
| `Super + A` / `Super + N` | Left panel (calendar, tasks, focus timer) / control centre |
| `Super + V` | Clipboard |
| `Super + Shift + S` | Capture (Tab switches to video) |
| `Super + L` | Lock |
| `Super + ,` | Settings |
| `Super + /` | Every shortcut, including yours |

Right click the empty sky to add widgets. Everything else lives in Settings.

## Updating

**Settings › About** checks GitHub for anything new and updates in one press; the shell reloads
by itself afterwards. That works for a `git clone` install, the installer's included.

**Installed before the About page existed?** Pull once by hand, and the button takes over from
there:

```sh
cd ~/.config/etea-shell   # or wherever you cloned it
git pull
```

If `git pull` stops because you changed some files yourself, put them aside first:

```sh
git stash        # set your changes aside
git pull
git stash pop    # bring them back (optional)
```

**Downloaded as a zip, without git?** Reinstall once with a clone. Your settings live in
`~/.config/etea`, not in the shell's folder, so they stay; the installer points the autostart at
the new folder:

```sh
git clone https://github.com/SDcold/etea-shell.git ~/.config/etea-shell
~/.config/etea-shell/install.sh
```

**Didn't reload by itself?** Restart it, or log out and back in:

```sh
qs kill -p ~/.config/etea-shell; qs -p ~/.config/etea-shell
```

## Configuration

Settings write to `~/.config/etea/settings.json`, and editing that file by hand works too: the
shell picks changes up live. A few things can be driven from scripts over IPC:

```sh
qs ipc -p ~/.config/etea-shell call desk state          # where the widgets are
qs ipc -p ~/.config/etea-shell call wake toggle         # stay awake on/off
qs ipc -p ~/.config/etea-shell call recorder stop       # stop a recording
qs ipc -p ~/.config/etea-shell call lock preview        # try the lock screen safely
```

`qs ipc -p ~/.config/etea-shell show` lists everything that's available.

Weather comes from [Open-Meteo](https://open-meteo.com) (with a rough location from
[ipinfo.io](https://ipinfo.io) unless you type a city), lyrics from [LRCLIB](https://lrclib.net).
Both are only asked while their widget is on your desktop.

## Hacking on it

The whole shell is QML; hot reload is on, so saving a file updates the desktop under your eyes.

```sh
scripts/dev.sh start   # (re)start ETEA from this folder
scripts/dev.sh logs    # follow what it says
scripts/dev.sh stop    # stop it
```

The visual rules live in `DESIGN_LANGUAGE.md`, the lock screen art and how it's traced in
`assets/lock/README.md`.

Want ETEA in your language? Copy `i18n/en.json`, translate each line, add it to
`Lang.languages` in `config/Lang.qml`, and send a PR. 💌

## Credits

- [Quickshell](https://quickshell.outfoxxed.me) by outfoxxed, which makes all of this possible.
- Icons: [Material Symbols](https://fonts.google.com/icons) (Apache 2.0).
- Font: [Poppins](https://fonts.google.com/specimen/Poppins) (SIL Open Font License).
- Emoji names: Unicode and CLDR data (Unicode License v3).
- Lyrics: [LRCLIB](https://lrclib.net). Weather: [Open-Meteo](https://open-meteo.com).
- Ideas borrowed with love from [end4's dots](https://github.com/end-4/dots-hyprland) and
  [Caelestia](https://github.com/caelestia-dots/shell).

## License

ETEA Shell is free software under the [GNU General Public License v3.0](LICENSE): use it, study
it, change it and share it, as long as what you share stays under the same terms. That covers
the code and the artwork made for it, the lock screen drawing included. Poppins and Material
Symbols keep their own licenses (`assets/fonts/OFL.txt` and `assets/icons/LICENSE.txt`).

Just give me some credits if my work helps you ;)
