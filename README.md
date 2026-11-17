# QuickShell Hyprland Desktop

A desktop shell for **Hyprland on Wayland**, written in QML and built on the
Quickshell runtime. The project provides a modular top bar, a
compact dashboard, a full control center, desktop widgets, a media player with
lyrics, notifications, a wallpaper manager, and a local AI chat panel.

The entire interface runs as a single Quickshell instance. There is no separate
daemon, panel process, or web view.

> **Scope:** this is a Hyprland-specific configuration, not a portable desktop
> environment. It is developed for Wayland sessions running Hyprland and is not
> intended to work on X11, on other compositors, or inside full desktop
> environments such as GNOME or KDE.

---

## Features

- **Modular top bar** — workspaces, active window, clock, Wi-Fi, Bluetooth,
  volume, notifications, system tray, media player, and an AI button. Modules can
  be placed into left, center, and right zones and resized or hidden from the
  Panel settings.
- **Dashboard popup** — quick toggles, volume and brightness, notifications,
  calendar, and a system monitoring page.
- **Control Center** — settings for appearance, the panel, media player,
  monitors, wallpaper, widgets, and animations.
- **Desktop widgets** — 14 widget types that can be placed on any monitor,
  moved, resized, and configured individually.
- **Monitor management** — enumerate outputs, identify them, change resolution,
  refresh rate, scale, rotation, and position, enable or disable an output, and
  apply changes without restarting the compositor.
- **Notifications** — a DBus notification server with popups, history, and a
  Do Not Disturb mode.
- **Media player** — MPRIS control, cover art, and lyrics from local `.lrc`
  files or online lyric services.
- **Wallpaper Studio** — browse a local image folder, preview wallpapers, and
  apply them per monitor through `hyprpaper`.
- **Theme system** — built-in color presets (including popular dark and light
  palettes plus gradient themes), custom accent colors, and adjustable opacity.
- **Local AI** — a chat sidebar that talks to a model served by LM Studio over
  its OpenAI-compatible HTTP API.
- **IPC control** — `dashboard` and `wallpaper` IPC targets that can be bound to
  compositor shortcuts.

---

## Interface

### Top bar

The bar is a layer-shell panel with configurable position (top, bottom, left,
right), thickness, margins, corner radius, and optional auto-hide. Its layout is
edited visually in **Control Center → Panel**:

- **Zones:** left, center, right, plus a pool of disabled modules.
- **Modules:** `workspaces`, `activewindow`, `clock`, `wifi`, `bluetooth`,
  `volume`, `notifications`, `tray`, `ai`, `mediaplayer`.
- **Per-module options:** size (`compact` or `normal`) and display mode
  (icon, text, or both). The media module additionally exposes cover art,
  artist, title, playback controls, and title length.
- **Workspace indicator styles:** `smart`, `dots`, `segments`, `blocks`, `bars`.

Clicking the clock opens the dashboard. The other modules open their own popups
(Wi-Fi networks, Bluetooth devices, volume mixer, notification history, tray
menu, AI sidebar, media panel).

### Dashboard

A compact popup anchored to the clock button with four pages:

- **Home** — Wi-Fi, Bluetooth, microphone mute, and Do Not Disturb tiles;
  volume and brightness sliders; the current notification list.
- **Calendar** — a month view with navigation.
- **Monitoring** — CPU, RAM, GPU, and VRAM usage.
- **Settings** — a shortcut into the Control Center.

### Control Center

A separate window with a sidebar and the following pages:

| Page | Contents |
| --- | --- |
| **Overview** | Hardware summary: CPU model and cores, GPU name and VRAM, total RAM. |
| **Appearance** | Theme presets (dark, light, gradient), per-color editing, opacity, gradient studio, and a custom theme library. |
| **Panel** | Visual layout constructor for the top bar (zones, module size, display mode), bar position, margins, radius, density, auto-hide, and spacing. |
| **Media player** | Media module status, cover art, lyrics appearance presets, colors, alignment, and behavior. |
| **Monitors** | Output list, identification overlay, resolution/refresh/scale/rotation/position, enable/disable, apply, and rollback. |
| **Wallpaper** | Wallpaper folder, fill mode, target monitor, startup restore, and a binding check. |
| **Widgets** | Widget catalog, adding widgets to a monitor, per-widget settings, and removal. |
| **Animations** | Global animation style (standard or spring), duration, and per-category toggles. |

### Notifications

The shell registers itself as the DBus notification server
(`org.freedesktop.Notifications`). Notifications appear as popups and are kept
in a history window. **Do Not Disturb** suppresses popups while still recording
history; its state is stored in `settings.json` under `Notifications.dnd`.

Do not run another notification daemon (for example `dunst` or `mako`) at the
same time — only one process can own the DBus name.

### Desktop widgets

Widgets are independent layer-shell surfaces managed by the widget engine. Each
instance can be placed on a specific monitor, moved, resized, duplicated (where
supported), and configured. The available types are:

| Widget | Description |
| --- | --- |
| Clock | Digital time, date, and weekday. |
| Calendar | Month calendar with navigation. |
| Weather | Current conditions and forecast from Open-Meteo (no API key). |
| System monitor | CPU, GPU, and RAM usage. |
| Network monitor | Throughput, IP address, interface, and VPN state. |
| Battery | Charge level, charging state, and power draw. |
| Storage monitor | Disk usage and free space. |
| System uptime | Uptime, boot time, and current time. |
| Workspace overview | Overview of Hyprland workspaces with switching. |
| Pomodoro | Work/break timer with session tracking. |
| Quick notes | Auto-saved plain-text notes. |
| Tasks | Task list with priorities, persisted to JSON. |
| Audio visualizer | Real-time audio visualization driven by `cava`. |
| Quick launcher | Application launcher that indexes `.desktop` files. |

### Media player

The media panel controls the active MPRIS player selected by the top bar media
module. It shows cover art, title, artist, album, playback controls, and a
progress bar, and it hides controls the player does not support.

Lyrics are fetched only on request. Sources, in order:

1. A local `.lrc` file next to the playing file, when the player exposes a file
   URL.
2. **LRCLIB** — artist, title, album, and duration.
3. **lyrics.ovh** — artist and title, used as a fallback.

### Wallpaper Studio

The wallpaper page scans a single folder (non-recursive) for `png`, `jpg`,
`jpeg`, and `webp` images, plus `avif` when the Qt AVIF image plugin is
available. Wallpapers are applied through `hyprpaper` using
`hyprctl hyprpaper`; the target can be all monitors or one specific output.
Fill modes are `fill`, `fit`, `stretch`, and `center`. The `center` mode
composites the image with ImageMagick's `magick` command.

The picker is a separate window and can also be opened with the `wallpaper`
IPC target. The last applied wallpaper can be restored at startup.

### Local AI

The AI sidebar is a chat panel that sends requests to **LM Studio** through its
OpenAI-compatible endpoint (by default `http://127.0.0.1:1234/v1/chat/completions`).
Conversation history is kept in memory for the current session.

The endpoint and model name are defined as `apiEndpoint` and `modelName` in
`components/AiSidebar.qml`. They must match a model that is actually loaded in
LM Studio; otherwise the panel will show an error response. LM Studio must be
running locally with its API server enabled.

---

## Requirements

### Required to start the shell

| Requirement | Why it is needed |
| --- | --- |
| **Linux with a Wayland session** | Layer-shell surfaces, popups, and window metadata are provided through Wayland and Hyprland IPC. |
| **Hyprland** | The shell imports `Quickshell.Hyprland`, reads workspaces and monitors, and calls `hyprctl`. |
| **`hyprctl`** | Used for monitor enumeration/application, wallpaper application, and workspace data. |
| **Quickshell** | The runtime that loads and renders every QML component. No minimum version is pinned in the source; use a current release that provides the modules below. |
| **Qt 6 with QML modules** | `QtQuick`, `QtQuick.Layouts`, `QtQuick.Controls`, `QtQuick.Dialogs`, and `QtQml.Models`. `QtQuick.Dialogs` is only used by the wallpaper folder picker. |
| **Quickshell modules** | `Quickshell`, `Quickshell.Io`, `Quickshell.Hyprland`, `Quickshell.Wayland`, `Quickshell.Widgets`, `Quickshell.Bluetooth`, `Quickshell.Services.Mpris`, `Quickshell.Services.Notifications`, `Quickshell.Services.Pipewire`, `Quickshell.Services.SystemTray`. |
| **Writable install directory** | Settings and widget state are written next to `shell.qml`. |

### Optional dependencies

None of these are required just to start the shell. Each one enables a specific
feature; without it that feature degrades or reports an error.

| Dependency | Used by | Behavior when missing |
| --- | --- | --- |
| `hyprpaper` | Wallpaper Studio | Wallpaper application fails with a backend error; the rest of the shell works. |
| NetworkManager / `nmcli` | Wi-Fi menu and dashboard Wi-Fi tile | The Wi-Fi list is empty and network actions fail. |
| BlueZ / `bluetoothctl` | Bluetooth menu, dashboard tile | Adapter state may still be visible through Quickshell, but device actions fail. |
| PipeWire | Volume module and mixer | Volume control is unavailable. |
| MPRIS-capable player | Media module and panel | The media module stays empty. |
| StatusNotifierItem applications | System tray module | The tray is empty. |
| `brightnessctl` | Dashboard brightness slider | Brightness changes do not apply; the slider still reads the current value from sysfs. |
| `cava` | Music Island visualizer and Audio Visualizer widget | The widget reports that cava is unavailable; the Music Island retries while a track is playing. |
| ImageMagick (`magick`) | Wallpaper `center` fill mode | Only the `center` mode fails; other fill modes work. |
| `qmake6` or `qtpaths6` | AVIF support detection | AVIF files are not listed; other image formats work. |
| `nvidia-smi` | GPU usage/VRAM metrics | NVIDIA metrics are unavailable; an AMD GPU is probed through sysfs. Intel GPUs are not reported and show `N/A`. |
| `socat` | Workspace Overview widget live updates | The widget still lists and switches workspaces, but stops refreshing automatically when windows or workspaces change. |
| `lscpu`, `lspci` | Overview page | CPU/GPU model names show as unavailable. |
| `df`, `ip`, `hostname` | Storage and network widgets | The corresponding widget shows no data. |
| `uptime` | Uptime widget boot time | Total uptime still comes from `/proc/uptime`; the boot-time line is empty. |
| A Nerd Font | Icon glyphs throughout the UI | Text still renders with a fallback font, but some icons may appear as missing glyphs. |
| LM Studio | Local AI sidebar | The AI panel cannot answer. |
| Internet access | Weather widget and online lyrics | Weather and network lyrics fail; local lyrics still work. |

### Tested environment

The project has been developed and tested on **Hyprland with the Lua
configuration provider under Wayland**. No minimum Quickshell or Qt version is
recorded in the source, and no other compositor, desktop environment, X11
session, or unlisted Hyprland version has been verified. Treat the tested setup
as a description, not as a guaranteed compatibility matrix.

---

## Installation

The shell expects to live in a writable directory, conventionally
`~/.config/quickshell`:

```text
~/.config/quickshell/
├── shell.qml
├── components/
└── ...
```

Copy or extract the project into that directory (or another writable location)
and keep the internal structure unchanged.

Do not install the project into a read-only system directory such as
`/usr/share`: the shell would start with default settings but could not save
changes.

## Running

From inside a Hyprland Wayland session:

```sh
quickshell -p ~/.config/quickshell/shell.qml
```

Quickshell creates its IPC socket under `$XDG_RUNTIME_DIR`, so commands such as
`quickshell ipc call ...` work only for the same user.

## Configuration

Configuration is edited through the Control Center. There is no hand-written
config file to create:

- On first start, `settings.json` is generated from the defaults in
  `components/Config.qml`. Missing keys are merged from the defaults on later
  starts, so old files keep working after updates.
- Widget instances are stored in `widgets.json` (schema version 1), created
  automatically on first launch with an empty instance list; `widgets.json.bak`
  keeps the previous copy when the file is rewritten.
- Monitor layout state is cached outside the project in
  `~/.local/state/quickshell/monitor-manager.json`.

Runtime files created in the project directory:

| File | Contents |
| --- | --- |
| `settings.json` | Panel, theme, animation, notification, widget, monitor, media player, and wallpaper settings. |
| `widgets.json` | Widget instances, positions, sizes, and per-widget settings. |
| `widgets.json.bak` | Previous copy of `widgets.json`. |
| `widget-notes-<id>.txt` | Text of a Quick Notes widget instance. |
| `widget-tasks-<id>.json` | Tasks of a Tasks widget instance. |
| `widget-cava-<id>.conf` | Generated cava configuration for an Audio Visualizer instance. |

These files contain user data and are excluded by `.gitignore`. The repository
itself ships only source code and defaults; a fresh clone starts with an empty
state and generates its own files.

## IPC

This README documents two user-facing IPC targets: `dashboard` and `wallpaper`.
They can be bound to compositor shortcuts:

```sh
quickshell ipc call dashboard toggle
quickshell ipc call dashboard open
quickshell ipc call dashboard close

quickshell ipc call wallpaper toggle
quickshell ipc call wallpaper open
quickshell ipc call wallpaper close
quickshell ipc call wallpaper refresh
quickshell ipc call wallpaper setFolder /path/to/wallpapers
quickshell ipc call wallpaper apply /path/to/image.png DP-1 fill
quickshell ipc call wallpaper state
```

`dashboard` opens, closes, or toggles the clock popup. `wallpaper` controls the
wallpaper picker; `apply` accepts a path, a monitor name (`All` for every
output), and a fill mode.

## Network access

The shell has no telemetry, accounts, or API keys. Requests are made only by
features that need them:

| Service | Trigger | Data sent |
| --- | --- | --- |
| Open-Meteo geocoding | Searching for or saving a city in the weather widget | City name and result language |
| Open-Meteo forecast | Refreshing the weather widget | Coordinates and temperature unit |
| LRCLIB | Requesting lyrics in the media panel | Artist, title, album, and duration when known |
| lyrics.ovh | Fallback when LRCLIB returns no lyrics | Artist and title |
| LM Studio (local) | Sending a message in the AI sidebar | Chat messages and model name, sent only to the configured local endpoint |

No authentication headers, tokens, or API keys are used for any of these
requests.

## Hyprland Lua configuration provider

Monitor management applies changes with:

```sh
hyprctl eval 'hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1, transform = 0 })'
```

`hyprctl eval` is an upstream Hyprland command, but it only works when Hyprland
uses the **Lua configuration provider** (`hyprland.lua`). The Lua provider is
available in Hyprland 0.57. On a classic `hyprland.conf` (hyprlang) setup the
rest of the shell works, but applying monitor changes from the Monitors page has
no effect.

For the same reason, the binding check on the Wallpaper page reads
`~/.config/hypr/hyprland.lua` and searches for a `SUPER + A` binding. With a
classic `.conf` configuration it reports the binding as missing even if one
exists.

## Compatibility and limitations

- **Hyprland and Wayland only.** X11, other compositors, and full desktop
  environments are not supported and not tested.
- **Monitor management requires the Hyprland Lua config provider.** Classic
  `hyprland.conf` users can still use the rest of the shell.
- **One notification daemon only.** The shell owns
  `org.freedesktop.Notifications`; disable any other notification daemon.
- **Wallpaper backend is hyprpaper.** There is no fallback to `swaybg`,
  `swww`, or similar tools.
- **GPU metrics are partial.** NVIDIA is read through `nvidia-smi`, AMD through
  sysfs. Intel integrated GPUs are not detected and show `N/A`.
- **Brightness** is read from `/sys/class/backlight` and written with
  `brightnessctl`; systems without a backlight device show no brightness
  control.
- **Interface language.** The interface is primarily in Ukrainian, with some English labels.
- **Local AI is not bundled.** It requires a separately installed LM Studio
  instance and a loaded model matching the configured model name.

## Project structure

```text
shell.qml                    Entry point: top bar, dashboard, IPC, sidebar, control center
components/
├── bar/                     Top bar modules and the bar layout host
├── settings/                Control Center pages and theme presets
├── widgets/                 Widget engine, registry, storage, and widget services
│   ├── services/            Weather, system metrics, storage, network data
│   └── widgets/             Individual desktop widget implementations
├── Config.qml               Settings schema, defaults, load/save
├── MonitorManager.qml       Hyprland output management
├── WallpaperService.qml     Folder scanning and hyprpaper integration
├── MediaPlayerPanel.qml     MPRIS panel and lyrics
├── AiSidebar.qml            Local AI chat
└── ...
```

---

## Notes

- The `settings.json` and `widgets.json` files in a working copy are personal
  state. They are ignored by Git and should never be committed.
