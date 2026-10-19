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

Settings → Plugins shows one searchable list with inline enable/disable
switches. Delete asks to remove a user plugin or disable a built-in plugin;
Install plugin stays at the top of the list, without a separate window.
Menu actions that summon a plugin follow its enabled state: disabling the
plugin hides those actions from browsing, search, and recent items. The plugin
stays in Settings → Plugins for re-enabling. Custom command wrappers can declare
their dependency with `"plugin": "plugin-id"` in the menu entry.
Enabled user-installed visual plugins automatically get an entry under Settings
and in launcher search. Names, manifest aliases/keywords, and bar-widget aliases
are indexed without editing the menu config. Selecting a result opens the panel;
management switches are searched only inside Settings → Plugins. Disabling or
removing a plugin removes its launch entry. Services without a visual entry
remain manageable in Plugins.

Panels using `qs.Ui.KeyboardPanel` automatically dock their first inline
`PanelHero` into the fixed, full-width header area when no `panelHeader` is
assigned. This also handles a hero inside a height-following wrapper: the
original collapses, while status bindings and trailing controls stay live in
the fixed header. An explicit `panelHeader` always takes precedence. Set
`PanelHero.autoDock: false` or `KeyboardPanel.autoDockHeaders: false` to keep
an inline header. Custom headers and other window types require explicit
integration; they are not detected by their text or appearance.
`qs.Ui.BarIconButton` measures standard and custom font glyphs against the
shared `Style.bar.iconSize` square using visible outline bounds, preserving
their proportions and drawing at an integer font size that fits the square.
Custom vector components with an `iconSize` property receive a drawing size
fitted to that same square. These are native font and drawing
sizes: the loader does not scale rendered glyphs or images. Custom icon ink is
centered with device-pixel translations rather than font line-box alignment.
A small Qt outline-measurement helper supplies cached glyph bounds where font
metrics include empty padding; it runs in batches and exits after each request.
Plugin colors and state bindings are retained. Set `useSharedIconSize: false`
to retain a custom component's original sizing. Other drawing components keep
their own geometry inside the shared canvas.

Built-ins can be disabled; only user-installed plugins can be
uninstalled. A disabled plugin retains its settings and bar position for
re-enabling. Plugins that provide a service and bar widget stop both when
disabled. The selected bar can also be disabled; the menu and shortcuts remain
available to turn it back on, with its widget layout preserved.

Installation accepts an HTTPS Git repository or a local folder with a root
`manifest.json`. It validates the schema and entry points and flags Omarchy
references for review; it does not guarantee runtime compatibility or run
install scripts. New plugins are installed disabled. Script-only Omarchy
extensions need adapting to Strata's plugin contract before installation.

| Plugin        | id                        | kinds                   | entry point                           |
|---------------|---------------------------|-------------------------|---------------------------------------|
| Bar           | `strata.bar`             | `bar`                   | `bar/Bar.qml`                         |
| Emojis        | `strata.emojis`          | `overlay`               | `emojis/Emojis.qml`                   |
| Clipboard mgr | `strata.clipboard`       | `overlay`               | `clipboard/Clipboard.qml`             |
| Strata menu  | `strata.menu`            | `menu`, `bar-widget`    | `menu/Menu.qml`, `menu/BarWidget.qml` |
| Notifications | `strata.notifications`   | `service`, `overlay`, `bar-widget` | `notifications/Service.qml`, `History.qml`, `BarWidget.qml` |
| Audio         | `strata.audio`           | `bar-widget`            | `panels/audio/Panel.qml`              |
| Bluetooth     | `strata.bluetooth`       | `bar-widget`            | `panels/bluetooth/Panel.qml`          |
| Clock         | `strata.clock`           | `bar-widget`            | `panels/clock/BarWidget.qml`          |
| Display Layout | `strata.monitor`        | `panel`                 | `panels/monitor/Panel.qml`            |
| Mouse         | `strata.mouse`           | `service`, `bar-widget` | `panels/mouse/Service.qml`, `panels/mouse/Panel.qml` |
| Privacy       | `strata.privacy`          | `service` | `services/privacy/Service.qml` |
| Network       | `strata.network`         | `bar-widget`            | `panels/network/Panel.qml`            |
| Battery & power | `strata.power`         | `service`, `bar-widget`  | `panels/power/Service.qml`, `panels/power/Panel.qml` |
| Media         | `strata.media`           | `service`, `bar-widget` | `services/media/Service.qml`, `services/media/BarWidget.qml` |
| System sounds | `strata.system-sounds`   | `service`               | `services/system-sounds/Service.qml` |
| Idle          | `strata.idle`            | `service`               | `services/idle/Service.qml`           |
| Night light   | `strata.nightlight`      | `service`               | `services/nightlight/Service.qml`     |
| Cursor locator | `strata.wiggle` | `service` | `services/wiggle/Service.qml` |
| Window switcher | `strata.window-switcher` | `service`             | `services/window-switcher/Service.qml` |
| Stage         | `strata.stage-control`  | `service`, `panel`, `bar-widget` | `services/stage-control/Service.qml` |
| Lock screen   | `strata.lock`            | `service`               | `lock/Service.qml`                    |
| OSD           | `strata.osd`             | `panel`                 | `osd/Osd.qml`                         |
| Polkit agent  | `strata.polkit`          | `service`               | `polkit/PolkitAgent.qml`              |

First-party bar-only widgets also carry manifests next to their QML files,
e.g. `bar/widgets/Workspaces.manifest.json`. Rich popup widgets live in their
own plugin directories, each with its own `manifest.json`.

## Bar

The built-in status bar and default full-bar option. Layout lives in the
top-level `bar:` subtree of `~/.config/strata/shell.json` (with the shell
providing [`defaults/strata/shell.json`](../../defaults/strata/shell.json) when
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

Quickshell-powered Strata command palette.
The menu UI lives in `menu/Menu.qml` as a first-party `menu` plugin and is
summoned through the shell (`strata-shell shell summon strata.menu ...`),
so it shares the long-running `strata-shell` process instead of starting a
second Quickshell instance.

The menu button uses the Fedora Nerd Font glyph (`nf-linux-fedora`, U+F30A)
in the bar's current foreground color. `strata-show-logo` shows the Fedora
mark and name using the terminal's current colors.

The menu definition lives outside the shell host code:

- defaults: `defaults/strata/strata-menu.jsonc`
- user extensions: `~/.config/strata/extensions/strata-menu.jsonc`

The shell parses both JSONC files at startup (with `watchChanges: true`
so edits take effect without a restart), evaluates `when:` / `checked:`
bash expressions in a single batched subprocess, and executes the
selected `action:` string directly via `Quickshell.execDetached`. The
long-running shell process keeps the parsed menu in memory, so the
keybind → IPC → visible path costs ~30ms cold.

The existing menu opens as a palette with grouped results for settings,
commands, applications, open windows, and menu destinations. Typing a plain
query searches those sources; `=2+3*4` calculates and copies the answer.
Prefix a query with `~` to find files by name, `cb` to search clipboard
history, or `g`, `dd`, `yt`, or `wiki` to search the web. Enter opens the
selected result. The root palette shows recently used entries above the
normal menu categories. These
preferences are stored in `~/.local/state/strata/menu-usage.json`.

## Configuration and quick controls

Clipboard history opens beside the cursor on its monitor, with a compact
stack of text and image cards. It flips at screen edges and keeps the desktop
undimmed. Type to search, use arrows and Enter to paste, Shift+Enter to copy,
Alt+Enter to open, or Delete to remove an entry. Clear all asks for confirmation.

Use the bar's individual panels for audio, displays, network, Bluetooth,
notifications, and power. Their settings buttons configure the relevant
feature directly.

**Menu → Settings → Tray icons** shows visibility switches for registered
tray apps and previously hidden icons. Enter or click toggles an icon while
keeping the menu open. Choices update the tray's `hidden` list in
`~/.config/strata/shell.json`; pinned icons and other tray options are kept.
An enabled unpinned icon appears in the tray drawer. Hiding an icon leaves
its application running.

Personal Hyprland appearance, input, and keybindings belong in
`~/.config/hypr/hyprland.lua` or files loaded from it. The bar layout and
widget preferences live in `~/.config/strata/shell.json`; shell style and
font-size overrides live in `~/.config/strata/shell.toml`.

## Coming soon

- `strata.theme-switcher` — folds theme switching into the shell.
