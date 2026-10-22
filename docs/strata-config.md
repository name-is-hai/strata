# Strata configuration

Versioned desktop defaults for the Fedora-based Strata desktop.

The RPM installs immutable defaults and the canonical shell below
`/usr/share/strata`. For compatibility, the package generates
`/usr/share/quickshell/strata` from the same source using hard links, so the
files occupy space only once. It does not replace files in a user's home
directory. Run this command once after installation:

```console
strata-apply-config
```

The command installs only missing user entry files and links the packaged
Quickshell configuration. Existing user files are left unchanged. Use
`strata-apply-config --dry-run` to preview changes or
`strata-apply-config --force` when you deliberately want to replace managed
files; backups are saved with a timestamp.

## Display fallback and login displays

Disabled outputs are synchronized to the separate greeter after a valid config
reload or Display Layout save. Only validated connector states are published;
the greeter does not execute personal Lua configuration.

When no usable display remains, Strata temporarily enables an available laptop
panel in both the desktop and greeter. Reconnecting an enabled external display
restores the saved layout. The desktop recovery does not rewrite monitor config
or remove manual-disable preferences, and it does not wake displays merely
because they were blanked by the lock screen or idle timer.

## Login keyring

Strata initializes GNOME Keyring when the Hyprland session starts, completing
the daemon setup performed by greetd's PAM login. This lets Chromium and other
Secret Service clients use the login keyring unlocked with your login password.
The keyring password must match the login password; passwordless logins can
still require a separate unlock. Existing keyring data is retained.

## Bar icon size

Set `[bar] icon-size = 16` in `~/.config/strata/shell.toml` to size bar
icons, including the battery. Visible font and vector artwork fits inside
this square, preserving its proportions and centering. Integer font sizes can
leave less than one pixel of unused space. There are no individual volume,
battery, or menu size multipliers. Tray images use the same square with their
original aspect ratio; transparent padding belongs to the supplied image.
Clock text and workspace numbers scale from the same setting, with visible
digits at 75% of the icon square (12px icons pair with 9px digits).
Input method labels, battery percentages, active-window titles, and default
custom command text share that text sizing. Explicit custom command font sizes
remain overrides.
`icon-slot` and `status-slot` control spacing separately.
With `scale-with-font = true`, icon size also follows `[font] base-size`.
The older `icon-canvas` key remains a fallback when `icon-size` is absent;
`icon-font` no longer controls a separate size.

## Current defaults

- Hyprland launched as a UWSM session
- Ghostty on `SUPER+T`
- Close window on `SUPER+Q`
- Nautilus on `SUPER+F`
- Default browser on `SUPER+B`
- Quickshell launcher on `SUPER+/`
- Focused application actions on `SUPER+M` (when the app exposes accessibility actions)
- Quickshell system menu on `SUPER+ESCAPE`
- Native Quickshell notification center
- Native clipboard history and emoji picker
- Screenshot selection on `PRINT`

The launcher searches Strata commands, settings, installed applications, and
open windows. Type `=2+3*4` to calculate; Enter copies the result. Window
results focus the chosen window. `SUPER+M` searches actions exposed by the
focused application's accessibility tree. Apps that expose no actions show an
empty list; Strata does not change their accessibility settings automatically.

## Plugins

Settings → Plugins opens one searchable list of installed plugins. Click a
plugin or press Enter to toggle it. Press Delete on a user plugin for removal
confirmation. Built-ins offer Disable instead of deleting package-owned files.
Install plugin is available at the top of the same list. Disabling preserves
settings and bar position. Built-in files remain package-owned; disabling a
plugin that also has a background service stops that service. Turning off Bar
unloads the bar while keeping keyboard shortcuts and the menu available.
Re-enable it from Settings → Plugins, or run
`strata-shell shell setPluginEnabled strata.bar true`. The selected bar and
widget layout are retained in `shell.json`; `bar.enabled` records the off state.

Battery & power is one plugin: its switch controls the battery icon and panel,
low-battery warnings, and the background power-profile watcher together. The
older `strata.battery` ID is an alias for `strata.power`; existing disabled
settings and commands continue to work.

Install plugin asks for an HTTPS Git repository URL or a local folder with
`manifest.json` at its root. A cancellable menu stays visible during source
checking. The review shows the version, compatibility note, and initial disabled
state as wrapped information above two choices: Install and Cancel. Install
leaves the plugin turned off; enable it later in Settings → Plugins.
Enabled user-installed panels, overlays, menus, and mounted bar widgets are
automatically available under Settings and searchable by their name and declared
aliases/keywords. Selecting a search result opens the plugin. To enable, disable,
or remove it, use Settings → Plugins; disabled plugins remain searchable there.
The check never runs install scripts and cannot guarantee runtime support.
Review source before enabling plugins, which run as your user. Standalone
Omarchy scripts and plugins using Omarchy-specific commands, services or paths
need adapting rather than automatic renaming.

User plugin files live in `~/.config/strata/plugins/`. Source review snapshots
live in `${XDG_CACHE_HOME:-~/.cache}/strata/plugin-installer/`; successful
installation or cancelling the review removes its snapshot. The CLI is `strata-plugin inspect SOURCE`,
`strata-plugin install REVIEW_TOKEN`, `strata-plugin remove ID`, and
`strata-plugin list`. The last command reports sources installed by this helper;
`strata-shell shell listPlugins` includes all shell plugins and enabled state.

## Theme picker

Style → Themes & backgrounds and `strata-theme-select` open the bundled Swatch picker. It
previews the wallpaper and shell palette while browsing; Enter applies the
selection, and Escape restores the previous preview. Favorites and hidden
backgrounds persist in XDG state. The Strata port uses Bash, jq, ImageMagick and Perl;
it does not run Python. Desktop double-click opens theme + background mode,
which applies the selected theme and wallpaper together. Right double-click opens
full-screen wallpaper adjustment directly: drag to reposition, scroll to zoom,
Enter to save and Escape to cancel. The picker starts at the active theme on every opening. Each theme lists only
its own wallpapers and restores its own last selected wallpaper, independently
of the wallpaper currently on the desktop. The
full-screen preview uses the desktop's saved per-monitor crop and zoom before
the handoff, and waits for the positioned desktop image to become ready.
The original image picker continues to serve general
image-selection requests. See `shell/plugins/theme-picker/README.md` for
upstream attribution, keyboard controls and port details.

## Web apps

Open Install → Install web app or Remove → Remove web app.
These open in Chromium app windows; the default browser
stays unchanged. The installer uses a themed floating terminal, downloads the
website's favicon when available, and creates entries in the Apps launcher.
Icon lookup prefers declared Apple touch icons and larger page icons, then
tries the site's standard icon paths and Google's favicon service. If every
lookup fails, installation still succeeds with a generic web icon.
The single-app flow offers to add another app after each install.

For multiple apps from the CLI, run `strata-webapp batch` and paste one website
per line. Use `Name | URL` to choose a
name; a plain URL uses its hostname. Submit the list with Ctrl+D:

```text
Mail | https://mail.example.com
https://example.org
```

CLI equivalents are `strata-webapp install "Name" "https://example.com"`,
`strata-webapp batch websites.txt`, `strata-webapp list`, and
`strata-webapp remove APP_ID`. Launchers, icons and app metadata are stored
under `~/.local/share` (or `XDG_DATA_HOME`). Reinstalling the same URL updates
its launcher. Removing a web app removes its launcher and metadata; Chromium
keeps the shared browser profile and sign-ins.

## Screenshots and recording

`SUPER+SHIFT+S` opens the Strata capture toolbar. Region, App, and Monitor
choose the target. Toggle Record to show four audio choices: No audio,
Desktop, Microphone, or Desktop + mic, then select the capture target.
App recording captures the window’s fixed screen area; moving or covering the
window changes what is recorded. `SUPER+SHIFT+R` stops a recording.
The menu under Tools → Capture → Screen recording offers the same three
targets and four audio choices, plus Stop recording.

## Opening files

Run `strata-default-files` to associate text and code with the Strata editor,
common images with Strata Snip's windowed editor, and videos with Celluloid. imv
handles other image formats. The text editor defaults to Neovim in Ghostty;
`strata-default-editor` selects another editor. File associations are stored in
the user's XDG `mimeapps.list`, so they can be changed independently.
Celluloid uses mpv's playback library; the standalone mpv player is not
required. The recorder uses FFmpeg's ffplay for its borderless webcam preview.
The `strata-open-image` launcher also finds local Strata Snip installations
when the file manager has a different PATH from the interactive shell.
Each image opens in an independent editor window. Starting screenshot capture
leaves these windows and their unsaved edits open.

The compact clipboard panel pastes a selected item on click or Enter;
Shift+Enter copies without pasting. Use the pin button or Ctrl+P to pin/unpin
an item. Pins appear first, persist across restarts and recopying, and survive
history trimming and Clear. Delete removes an individual item, including a pin.

The clipboard's Alt+Enter action opens a copied file path or `file://` link
using those associations. Plain text opens in the editor, an image opens in
Strata Snip, and a standalone web link opens in the browser. Screenshot
notifications keep their separate edit action.

## Cursor themes

Hyprcursor theme tools are included in `hyprland-utilities` and required by
`strata-config` for fresh installations. Fedora’s `hyprcursor` package supplies
`hyprcursor-util` for working with Hyprcursor themes. Its public Hyprlang
runtime is required explicitly because Hyprland’s private library path is not
available to the public tool.
Hyprland keeps its own compatible runtime library in its private vendor path.
Strata defaults to **Win11OSX at 26px**, bundled in both Hyprcursor and
XCursor formats. Artwork is by [MOYASH](https://www.gnome-look.org/p/2334253).
The original archive's license, attribution and download checksum ship with
it. The archive specifies CC BY-NC-ND; this takes precedence over the page's
conflicting CC BY-SA label for our packaging. Hyprcursor uses the original
96px raster artwork and animations without redrawing. Complete frames are
pre-rendered at 15 sizes from 24 to 96px, including 40px and common display
scale sizes. Hyprcursor selects a complete frame instead of entering its
PNG resampling path, which can clip downscaled artwork. The matching XCursor
fallback retains all four original sizes (32, 48, 64 and 96px). Personal
configuration overrides the defaults.

Install compiled themes under `~/.local/share/icons/<theme>/` and apply one with
`hyprctl setcursor <theme> 26`. Persist the selected Hyprcursor theme and size
in `~/.config/uwsm/env` using `HYPRCURSOR_THEME` and `HYPRCURSOR_SIZE`.
Keep an XCursor version configured with `XCURSOR_THEME` and `XCURSOR_SIZE`
for applications that do not support Hyprcursor. Wiggle reads these settings.

## Finding the cursor

Shake a mouse or wiggle one finger rapidly on the touchpad to enlarge the pointer temporarily. Strata’s Wiggle
service uses the current cursor theme, grows up to 8× with repeated shakes
for vector themes,
and returns to normal after a short pause. Raster themes are capped at the
source image resolution, accounting for display scaling, to prevent pixelated
enlargement. Two or more fingers, direct
touchscreens, and keyboard-capable input nodes are ignored. Touchpad detection
resets when you lift a finger or start a gesture. Pointer hotplug is supported.

The RPM builds its monitor from source and grants mouse/touchpad active-seat
access through udev; input-group membership is unnecessary. Disable or enable
it with `strata-shell shell setPluginEnabled strata.wiggle false` or `true`.
The monitor restores the native cursor after shell termination, and the service
restores it and restarts the monitor if that helper fails.

## Touchpad gestures

Strata uses Windows-style three-finger gestures and four-finger workspace
switching. Swipe three fingers left or right to switch between recent
apps, up to open the window overview, and down to show or restore the desktop.
Each three-finger direction can be changed in the Strata menu under
Settings → Stage & gestures → Trackpad.
Disabling Stage in Settings → Plugins stops Strata's three- and four-finger
touchpad gestures. Re-enabling it restores the configured actions; keyboard
window switching remains available through the separate Window switcher plugin.
The three-finger quick overview and `ALT+TAB` use the same Stage-styled window
grid. A quick `ALT+TAB` switches directly; holding Alt for about 180 ms shows
the grid, and releasing Alt selects the highlighted window.
Swipe four fingers horizontally to the nearest workspace with windows in that
direction, including desktops hidden by a three-finger-down swipe. From an
occupied workspace with none ahead, one adjacent blank workspace is available;
another swipe cannot continue into a second blank. Swipe four
fingers up to open Strata Stage, with live
previews and desktop thumbnails; swipe down to see the focused app's windows.
Two-finger pinch remains available to applications for zooming.

`SUPER+A` also opens Strata Stage, and `SUPER+ALT+A` shows the focused app's
windows. Open the Strata menu → Settings → Stage & gestures to configure it. Its
appearance follows the current Strata theme and system font.

The gesture definitions live in `defaults/hypr/gestures.lua` and load from the
standard Hyprland entry file. The desktop gesture temporarily stores the
current workspace's windows and restores them when toggled again. Custom
mouse-drawn gestures and ring menus can be added
separately; Strata does not take over the mouse's right button by default.

The initial Quickshell release provides the bar, workspaces, tray, clock,
application launcher, system menu, notification center, clipboard history,
emoji picker, and keybinding help.

## Night light

Left-click the Night Light indicator to open its panel. Set color temperature
from 1000K to 6500K, use the Day / Evening / Night / Candle presets, or switch
between manual and automatic modes. Automatic mode changes temperature around
sunrise and sunset with a gradual transition. Enter latitude and longitude in
the panel to calculate local solar times; without coordinates it uses 06:00 and
18:00. The values are calculated locally and no location request is sent over
the network. Pause the automatic schedule for one hour or until sunrise. Right-
click the indicator to switch between the current manual temperature and day
light.

The service stores its schedule in `~/.config/strata/nightlight.json` and
continues to support `strata-toggle-nightlight` and the `nightlight` shell IPC
target. This adapts the controls and schedule concepts from
[omarchy-nightlight](https://github.com/key-tone/omarchy-nightlight) to Strata's
theme-aware bar and existing `hyprsunset` service.

## Media controls

The compact Media bar icon opens a now-playing panel on left-click or
Super+Ctrl+M. Right-click plays/pauses, middle-click skips forward, and scrolling
selects the previous/next track. The panel shows the player, artwork, track
information, playback controls, and a seek bar when the player reports duration.
Multiple sources can be selected individually. Unsupported player actions are
disabled. Within the panel, Space plays/pauses, Left/Right seek five seconds,
Up/Down select a source, and Escape closes it.

The widget is `strata.media`; enable or disable it from the menu's tray controls.
Its inline shell.json settings are `hideWhenPaused` (default false) and
`panelWidth` (default 380). This adapts the MIT-licensed
[media-control panel by debba](https://github.com/debba/omarchy-media-control)
and reuses Strata's existing media service and XF86 bindings.

## Wallpaper position

Left double-click opens the combined theme and background picker. Right
double-click opens **Adjust background** directly in full screen.

For still images, select a monitor, drag the preview, choose Fill / Fit / Stretch /
Center, and adjust zoom. Changes preview live. Cancel, Escape, or clicking outside
discards the preview; Save stores it per image path and monitor in
`~/.config/strata/backgrounds.json`. The watched JSON file can also be edited
directly. Reset restores centered Fill at 100% zoom. Video backgrounds retain
their separate renderer and do not expose these image crop controls.

## Mouse settings

Open **Settings → Mouse & Touchpad** from the menu to control pointer and scrolling behavior, plus
touchpad tapping, dragging, and disable-while-typing. Mouse and touchpad
pointer speed and acceleration are independent: touchpads receive per-device
overrides, including when reconnected. Each pointer slider uses 0–100% in 5%
steps, with 50% representing the default sensitivity. Changes preview live;
closing the panel discards unsaved changes. Save writes
`~/.config/hypr/mouse.lua`, loaded by Strata's default input configuration;
later personal Hyprland overrides take precedence. The header shows the mouse
name and available battery reading. The panel is menu-only and remains available
without a bar icon. Mouse battery readings
are discovered through UPower, without a device-specific raw HID helper.
Devices with no battery interface omit the battery reading. Low-battery
alerts name each mouse at 20% and again at 5%, rearming after charging or
recovery above 25%. The service runs even while the panel is closed.

## Sleep and idle settings

The Power panel stores auto-lock, display-off, and sleep timers separately for
Power Saver, Balanced, and Performance in
`~/.config/strata/idle-settings.json`. Switching the active power profile also
switches the timers. Existing single-set idle settings are copied to all three
profiles on first use so a migration does not change the current delays.

The Power panel keeps battery health, capacity, temperatures, the draw graph,
and recent CPU activity visible above its settings cards. **Screen, sleep & lock**
and **Lid & power button** expand to show their controls. Timer dropdowns offer
presets and a Custom option for hours/minutes. Under **Lid & power button**, select **On battery** or
**Plugged in** to choose lid-close and physical power-button actions separately.
These actions follow the power source even when both sources use the same
power plan. Existing lid settings are copied to both sources; the power button
keeps its system default until customized. Custom button actions apply to a
normal press; holding the physical button for a hardware power-off is unchanged.
The power-menu action requires an unlocked session. Custom handling releases
its logind inhibitor when the shell exits or System default is selected.

The suspend-then-hibernate delay still applies to all profiles.
The Stay Awake indicator only toggles a temporary pause for automatic
display-off and sleep; it does not block a manual suspend.

## Display wake after sleep

Hypridle runs `strata-system-wake` after resume to restore DPMS and brightness.
Outputs must not be disabled and re-created while the session is locked: losing
a lock surface during resume can crash the locker and leave Hyprland's failsafe.
External displays that still need cable reconnection require graphics-stack
investigation; an automatic output-removal workaround is not enabled.

## Lock-screen and login power controls

The greeter and session lock share `shell/Ui/LockScreenView.qml`: wallpaper,
clock, password field, account label, feedback, and power buttons. The greeter
enables account switching and additional authentication prompts; the session
lock supplies PAM, fingerprint status, and the optional video feed. Visual
changes belong in the shared view and apply to both screens.

`python3 scripts/tests/lock-screen-view.py` checks input, prompt and busy/error
states, account switching, fingerprint feedback, power signals, and identical
rendering without contacting PAM or greetd or running power actions.

The lock screen sends Sleep, Shutdown and Restart through `systemctl` with
interactive authentication disabled. Refused actions show an error on the lock
screen; repeated clicks are ignored while a request is running. Tab and Space
can activate the power buttons. The visual lock preview disables these actions.
At login, greetd authenticates the user while a separate Hyprland session
shows the Quickshell greeter. The form appears on Main and the background
covers every connected output.

## Source layout

The unified Strata repository contains both source and the published DNF
repository. `packaging/strata-config.spec` maps the desktop source as follows.

| Source                          | Installed path                       |
| ------------------------------- | ------------------------------------ |
| `bin/` and bundled executables   | `/usr/share/strata/bin` only          |
| `shell/`                        | `/usr/share/strata/shell`            |
| `defaults/`                     | `/usr/share/strata/default` (Strata shell config also under `/usr/share/strata/config/strata`) |
| `themes/`                       | `/usr/share/strata/themes`           |
| `docs/`                         | `/usr/share/strata/docs`             |
| `runtime-version`               | `/usr/share/strata/version`          |
| `config/hypr`, `config/uwsm`, `config/xdg-desktop-portal` | `/usr/share/strata/user-config` |
| `scripts/`                      | Development tests and Git-hook adapter; not installed |

Commands have one installed location: `/usr/share/strata/bin`, with no copies
or compatibility links in `/usr/bin`. UWSM adds it to `PATH`; the greeter and
installer initialize it themselves, and system services and privileged helpers
use absolute paths. Outside a Strata session, use the full command path or add
`export PATH=/usr/share/strata/bin:$PATH` to that session's environment.

`defaults/` is the single source directory for shipped desktop defaults, assets,
and templates. Its `strata/` subdirectory also contains shell defaults,
menu-extension templates and hook samples. Installed locations retain the
existing runtime paths; `config/` holds per-user entry files.

Personal Ghostty, Neovim, Zsh, Tmux, Git, Fcitx5, Zed, and Mise settings are
kept in the separate `dotfiles` repository and are never packaged by Strata.

## Wireless display and media casting

Use **Tools → Toggle → Cast** in the menu (or search “Cast”). Off is the
fresh-install default. On starts receiver discovery and shows one **Cast** icon.
Off hides that icon, stops discovery and active casting, and stops the media
daemon. The switch is saved in shell.json as `strata.cast.discoveryEnabled`.

The icon opens **Screen** and **Media** tabs and remembers the last tab.
**Screen** discovers Miracast and AirPlay receivers: choose Mirror or Extend
and connect. Extended screens are temporary monitors in the display-layout
panel. Miracast needs Wi-Fi Direct; AirPlay needs a reachable receiver on your
network. AirPlay may ask for a PIN or password. Closing the panel preserves a cast. While the master switch is on, it
checks for wireless displays every 30 seconds when idle; Refresh also searches
again. Connection-state checks keep the icon current.

**Media** sends a selected local file, or a local file reported by an MPRIS
player, to DLNA, Google Cast, or experimental AirPlay receivers. Playback,
seeking, receiver volume, audio boost and supported text subtitles are
available. A highlighted icon and status dot indicate casting, and its tooltip
names the receiver. Disconnect/Stop ends a session. Remote web streams and DRM
playback are not guaranteed.

CLI controls:

```sh
strata-toggle-cast
strata-bar set strata.cast discoveryEnabled true --json
strata-bar set strata.cast discoveryEnabled false --json
strata-shell shell toggle strata.cast
```

`strata-config` requires the `strata-casting` meta-package, which pulls in
`strata-waycast`, `strata-doubletake`, and `strata-cast`. Build those with
`bin/strata-build-rpms config`; this builds the desktop config and casting
backends from the same source spec. The `all`
target includes them. The installer enables RPM Fusion Free for Miracast’s
GStreamer x264 encoder and `libavcodec-freeworld` for media transcoding. Backends and the media user unit are RPM-owned; no
Rust toolchain or source build is needed on an installed desktop. The media
daemon starts on demand, and the privileged Wi-Fi Direct helper activates
through system D-Bus.

Miracast networking uses a dedicated `strata-wireless` firewalld zone, attached
only to the helper-validated P2P interface, with ports limited to the session’s
negotiation and removed on disconnect. Media casting requests a runtime-only
receiver/listener-specific firewalld rule through Polkit and removes it when
stopped. The root networking helper owns media allowances and watches a dedicated
D-Bus connection: losing the casting process removes its allowance automatically.
A root-owned runtime journal is written before opening the port. Failed cleanup
keeps the journal and retries; helper crashes are recovered by systemd’s stop
hook and startup cleanup. These recovery steps do not need another authentication
prompt. PINs travel over stdin rather than command-line arguments.

AirPlay Extend installs its upstream Hyprland portal-picker wrapper on first
use, which can restart the portal and interrupt an existing screen share.
The panel serializes setup with Miracast. Actual TV compatibility, Wi-Fi Direct
roles, and supported codecs still require receiver testing.

Settings: `~/.config/strata/cast/`; runtime state:
`$XDG_RUNTIME_DIR/strata-wireless-display/` and `$XDG_RUNTIME_DIR/strata.cast/`.
Logs: `journalctl --user -u strata-castd` and
`journalctl -u strata-waycast-networkd`. Wireless CLI:
`strata-wireless-display-ctl state`, `scan-start`, `mirror <id>`, `extend <id>`,
`disconnect`. Media CLI: `strata-cast status`, `discover`, `connect <ip> <file>`.

Adapted under MIT from [Wireless Display](https://github.com/alchemy/omarchy-wireless-display)
and [UniCast](https://github.com/liberuum/unicast). Screen backends:
[Waycast](https://github.com/alchemy/waycast) and
[Doubletake](https://github.com/alchemy/doubletake) (LGPL). Vendored revisions
are recorded in each backend’s `UPSTREAM` file; release archives are checksum
verified in `packaging/strata-config.spec`.


### Login greeter colors

The Strata login screen follows the active theme's `colors.toml` and `[lock]`
colors in `shell.toml`, including overrides in `~/.config/strata/shell.toml`.
Theme changes and session startup run `strata-greeter-theme-sync`. After editing
lock colors manually, run that command to synchronize the login screen too.
Use `strata-greeter-theme-sync --print` to inspect the palette without changing it.

The greetd user cannot read private theme files. A narrowly authorized polkit
helper publishes ten validated hex colors into the public greeter theme file.
Changes appear when the greeter next starts. Shared login screens
use the palette most recently synchronized by an active local user. Gradient
borders use the first color stop, matching Strata's flat color consumers.

### Independent monitor workspaces

Each output has its own desktop numbers. `Super+1` through `Super+0` select
local desktops 1–10 on the focused output; adding Shift moves the focused
window there, and Shift+Alt moves it without following. `Super+Tab` cycles
that output's desktops, and `Super+Ctrl+Tab` returns to its previous desktop.
The bar and Stage display local numbers, with 1–5 available on each output.

Four-finger horizontal swipes use the output under the pointer. They jump to
the nearest occupied desktop, including windows hidden with three-finger
down. Beyond the occupied desktops, a swipe allows one empty neighbor.

`defaults/hypr/workspaces.lua` maps local numbers to unique Hyprland IDs:
`(monitor.id + 1) * 100 + local_number` (local numbers 1–99). For personal
rules targeting a desktop, use the mapped ID rather than a global 1–5.
Existing desktops are adopted on reload; an unplugged output's desktops are
temporarily adopted by the receiving output without merging occupied groups.
Reconnecting restores each window's original output and local desktop, including
hidden windows and the active desktop. This memory survives config/theme reloads
within the session. A window deliberately moved while unplugged keeps its new
assignment. Stage pins and custom names follow the output name and local
number when monitor IDs change. Scratchpads are unchanged.

In the Display panel, **Main** places an output at the layout origin and saves
that choice in `~/.config/hypr/monitors.lua`. Strata also marks it as the
XWayland primary output on startup, after hotplug, and when applying a layout.
Hyprland has no compositor-wide primary-output setting; Wayland apps continue
to use the focused output.

The greetd greeter uses a separate, minimal Hyprland session. Quickshell puts
the password form on the connected Main output saved in
`/etc/strata/main-monitor`, or the first display if Main is absent, and draws
the background on every output. If the graphical greeter fails before login,
`agreety` provides a text login on the same VT. The user's Strata session
starts only after greetd accepts authentication and the greeter exits.

`Super+Shift+Alt+Left/Right/Up/Down` moves the entire active desktop to the
neighboring output, including windows hidden by three-finger down. It keeps
the local number when free, otherwise uses the first free number. This is an
intentional move: the destination becomes those windows' new home.

In Stage, right-click a desktop for **Rename** or **Move workspace to…**.
Each destination shows its output name and the workspace number it will use.
Removing a desktop updates Stage's saved layout; creating/selecting that
number again brings it back. The bar retains its 1–5 shortcut placeholders.

Keyboard feedback is provided by one built-in plugin, `strata.keyboard-osd`,
adapted from Keyglow (0x1ocean) and Lock Keys OSD (trinity-bytes). It handles
US/VN input-method switches, physical Hyprland layout changes, Caps Lock,
and Num Lock through the existing themed Strata OSD. It needs no extra
packages and ships in `strata-config`.

The Fcitx5 observer runs once across all monitors. Initial/repeated readings
are silent, and physical layout events ignore virtual keyboards and focus
synchronization. Popups use full names such as English (US) and Vietnamese
(Unikey); other methods use Fcitx5's display name automatically. The compact
bar indicator is unchanged. Vietnamese Unikey still needs Fcitx5. Caps Lock uses normal
capitalization by default; mapping it to Compose disables Caps Lock toggling.
Lock detection follows the first available kernel LED source per lock and
falls back to Hyprland if that source is unavailable.

Inspect all keyboard feedback with `strata-shell keyboard-osd state`.
Disable the plugin with `strata.keyboard-osd` in `disabledPlugins` inside
`~/.config/strata/shell.json`. Layout options go in a `plugins` entry with
`id: "strata.keyboard-osd"`: `labelStyle` (`full`, `language`, or `layout`),
`durationMs` (200–5000), and `showIcon` (boolean).

Strata Shortcut Guide combines Omakeez's visual shortcut guide with Key
Promoter's menu-action reminders in one plugin. Hold Super for 500ms, add
modifiers to narrow the guide, and release to dismiss it. It follows the
focused display and the current theme. Tools → Toggle → Shortcut Guide is
the persistent master switch for both features; it also makes the packaged
Lua observer inert while off. No additional bar icon is installed.
Settings → Shortcut Guide opens the settings panel for delay, starting
modifiers, fullscreen behavior, top offset, and shortcut reminder position.
Changes save immediately. The guide uses its original top-edge layout;
reminders are centered by default.

Personal options live in `~/.config/strata/shortcut-guide.json`. Defaults are
`enabled: true`, `guideDelayMs: 500`, `showInFullscreen: false`, and
`promoterEnabled: true`. Only Super starts the guide by default; Shift, Ctrl,
and Alt still narrow a guide already opened with Super. Optional standalone
roots use `guideShiftEnabled`, `guideCtrlEnabled`, and `guideAltEnabled`.
Menu reminders match the selected command/app to effective bindings and do
not infer menu use from closing it. They do not teach shortcuts inside apps.

The Hyprland observer is installed through the packaged input defaults;
personal Hyprland files are not rewritten. It uses compositor events rather
than `/dev/input`. A short-lived Python helper generates the binding catalog
at startup/configuration changes; Lua/LuaJIT resolves command metadata for
menu reminders. The package includes the plugin and both upstream licenses.
Inspect it with `strata-shell shortcut-guide diagnostics` and use
`strata-shortcut-guide on|off|toggle|status` from a terminal.

## Privacy indicators

The Indicators bar widget groups camera access, microphone access, screen
sharing/recording, night light, stay awake and hotspot status in one place.
Camera, microphone and screen sharing appear only during access; hovering the
group does not reveal them while idle. Screen sharing uses a monitor icon.
Hover reveals idle manual controls, and hovering active privacy icons shows
their app details. Click the microphone
to mute/unmute, scroll to change input volume, or middle-click for audio settings.
The tooltip shows input volume and app names when available. Screen recording
turns red and retains its click-to-stop action for Strata's recorder. Choose
which statuses to show in the Indicators widget settings. Privacy monitoring
remains a shared service; it no longer supplies a separate bar widget.

One shared service observes PipeWire graph metadata and checks the current
user's open camera/ALSA capture handles every two seconds. It never opens
cameras, reads microphone audio, or captures screen content. Desktop-audio
monitor streams do not count as microphone use. Indicators follow device
access, not whether a meeting application or browser tab is open. PipeWire
portal screen sessions and wf-recorder/gpu-screen-recorder are covered; tools
that bypass those interfaces may not expose screen capture. Direct device
access by processes whose handles are inaccessible cannot be identified.

### Image tools

Tools → Convert or resize image provides conversion, resizing, and compression.
Conversion exports a new JPG, PNG or WebP and never replaces an
existing file. Animated inputs export their first frame. Transparent areas
become white when exporting JPG.

```sh
strata-image-convert photo.png --format webp --size medium
strata-image-convert photo.jpg --format jpg --size original --quality 75
strata-image-rotate photo.png
```

Size presets cap width at 3160 (high), 2160 (medium), or 1080 (low) pixels;
`original` keeps the dimensions. Images are never enlarged. With no arguments,
the commands offer a file chooser. Rotation saves into the selected file;
conversion preserves its source.

The packaged imv config binds Ctrl+R to saved rotation and Ctrl+Shift+C to
conversion. imv reloads files changed on disk. `strata-apply-config` installs
this config for a new user while preserving existing configurations.

Wallpaper loading reads the first frame's dimensions with
`magick identify -ping` before decoding, and retains the per-display decode-size
cap. This reads metadata without adding a full-size wallpaper decode.

## Installation diagnostics

Run `strata doctor` as the desktop user to check core commands and RPMs, installed
runtime files and version, personal shell JSON, portal preference, the current
wallpaper target, media/portal services and live Hyprland/Quickshell IPC. It also
checks that the active desktop can report a default audio output. This does not
prove that every application's capture stream follows that output.

The command only reads state: it does not repair settings, install packages,
restart services, play media or change volume. Outside a desktop session,
unavailable session checks are marked skipped. A required failure exits 1;
warnings alone exit 0. The hook examples and optional plugin directories do not
need to exist for the installation to pass.

From the source checkout, use `bin/strata doctor`. The installed command becomes
available after rebuilding and installing the config RPM. Diagnostic checks use
the installed runtime selected by `STRATA_PATH`, not the source tree's planned
release version. Run `scripts/tests/doctor.sh` for isolated checks using mock
services and a temporary home directory.
