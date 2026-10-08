# First-party plugins

These plugins ship with Strata and are discovered by the shell at startup.
They use the same `manifest.json` contract as third-party plugins; the
only difference is that the shell flags them with `__isFirstParty: true`.
First-party non-bar plugins are enabled unless listed in `disabledPlugins[]`;
`strata.bar` is the default bar option and becomes inactive only while another
`kind: "bar"` plugin is selected. Services and keep-loaded panels are mounted
at startup; other panels, overlays, and menus are loaded on demand.

User-installed plugins live alongside these conceptually but on disk under
`~/.config/strata/plugins/<plugin-id>/` rather than in this directory.

| Plugin        | id                        | kinds                   | entry point                           |
|---------------|---------------------------|-------------------------|---------------------------------------|
| Bar           | `strata.bar`             | `bar`                   | `bar/Bar.qml`                         |
| Emojis        | `strata.emojis`          | `overlay`               | `emojis/Emojis.qml`                   |
| Clipboard mgr | `strata.clipboard`       | `overlay`               | `clipboard/Clipboard.qml`             |
| Strata menu  | `strata.menu`            | `menu`, `bar-widget`    | `menu/Menu.qml`, `menu/BarWidget.qml` |
| Notifications | `strata.notifications`   | `service`               | `notifications/Service.qml`           |
| Audio         | `strata.audio`           | `bar-widget`            | `panels/audio/Panel.qml`              |
| Bluetooth     | `strata.bluetooth`       | `bar-widget`            | `panels/bluetooth/Panel.qml`          |
| Clock         | `strata.clock`           | `bar-widget`            | `panels/clock/BarWidget.qml`          |
| Monitor       | `strata.monitor`         | `bar-widget`            | `panels/monitor/Panel.qml`            |
| Network       | `strata.network`         | `bar-widget`            | `panels/network/Panel.qml`            |
| Power         | `strata.power`           | `bar-widget`            | `panels/power/Panel.qml`              |
| Media         | `strata.media`           | `service`, `bar-widget` | `services/media/Service.qml`, `services/media/BarWidget.qml` |
| Battery       | `strata.battery`         | `service`               | `services/battery/Service.qml`        |
| Idle          | `strata.idle`            | `service`               | `services/idle/Service.qml`           |
| Night light   | `strata.nightlight`      | `service`               | `services/nightlight/Service.qml`     |
| Lock screen   | `strata.lock`            | `service`               | `lock/Service.qml`                    |
| OSD           | `strata.osd`             | `panel`                 | `osd/Osd.qml`                         |
| Polkit agent  | `strata.polkit`          | `service`               | `polkit/PolkitAgent.qml`              |

First-party bar-only widgets also carry manifests next to their QML files,
e.g. `bar/widgets/Workspaces.manifest.json`. Rich popup widgets live in their
own plugin directories, each with its own `manifest.json`.

## Bar

The built-in status bar and default full-bar option. Layout lives in the
top-level `bar:` subtree of `~/.config/strata/shell.json` (with the shell
providing [`config/strata/shell.json`](../../config/strata/shell.json) when
the user has no file). See [`bar/README.md`](bar/README.md) for the widget catalogue
and customization schema.

## Lock screen

Session-lock surface using Quickshell's native `WlSessionLock` and two
separate PAM services: `strata-lock-password` for password auth and,
only when fingerprints are enrolled, `strata-lock-fingerprint` for
fingerprint auth. It mirrors the previous lock screen field dimensions,
colors, blurred wallpaper, placeholder, and Hyprland-driven corners.
The plugin sets `keepLoaded: true` so a plugin hot-reload (for example
an installed bar widget changing on disk) does not destroy the lock
client while Hyprland still holds the session lock.

## Polkit agent

Theme-aware authentication dialog for privileged actions. It uses
Quickshell's native `Quickshell.Services.Polkit.PolkitAgent` backend and
runs inside the long-lived `strata-shell` process, replacing the old
`polkit-gnome-authentication-agent-1` autostart.

## Strata menu

Quickshell-powered Strata command menu.
The menu UI lives in `menu/Menu.qml` as a first-party `menu` plugin and is
summoned through the shell (`strata-shell shell summon strata.menu ...`),
so it shares the long-running `strata-shell` process instead of starting a
second Quickshell instance.

The menu definition lives outside the shell host code:

- defaults: `default/strata/strata-menu.jsonc`
- user extensions: `~/.config/strata/extensions/strata-menu.jsonc`

The shell parses both JSONC files at startup (with `watchChanges: true`
so edits take effect without a restart), evaluates `when:` / `checked:`
bash expressions in a single batched subprocess, and executes the
selected `action:` string directly via `Quickshell.execDetached`. The
long-running shell process keeps the parsed menu in memory, so the
keybind → IPC → visible path costs ~30ms cold.

## Coming soon

- `strata.theme-switcher` — folds theme switching into the shell.
