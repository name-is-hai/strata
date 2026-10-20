# Package usage and overlap report

Audit date: 2026-10-19. Target: the working tree prepared for Strata 1.0.0.

Packaging now has separate Ghostty, Zen and UWSM specs and an independent
lock-auth build target. Dependency inventories below describe the earlier
audit; use the current specs and [release guide](releasing.md) for build targets.

This report reviews the five RPM specs, installer, shipped configuration,
commands, shell plugins, and native capture code. It distinguishes a package
with no shipped caller from a service, library, plugin, or desktop application
that does not need a literal command invocation. After the audit, the user approved removing `hyprlock`, `playerctl`, and
`pavucontrol` from default requirements. Those dependency edges are now removed;
the Hyprlock build and RPM were subsequently removed, along with the unused
`ghostty-vt-devel` RPM. Ghostty's terminal and runtime library are retained. The user also approved
removing Buildah and Skopeo from default requirements; those edges are removed. Other recommendations
remain pending. Personal configuration and installed packages were not modified.

These are source-level findings, not a complete RPM dependency-solver or fresh
installation test. Generated ELF dependencies, Fedora transitive dependencies,
user extensions, and personal commands may retain packages after a direct
requirement is removed. Disk savings therefore remain unmeasured.

## Approved removals and remaining candidates

| Package | Evidence | Decision and consequence |
| --- | --- | --- |
| `hyprlock` | Previously required by [strata-config.spec](../packaging/strata-config.spec) and the [utilities metapackage](../packaging/hyprland-utilities.spec). [strata-system-lock](../bin/strata-system-lock) calls the Quickshell lock screen. No executable `hyprlock` invocation was found in shipped defaults. | Removed from default requirements and no longer built or published. |
| `ghostty-vt-devel` | SDK headers, linker symlink and pkg-config metadata. No shipped component builds against this SDK. | No longer packaged or published. Ghostty and its versioned runtime library remain. |
| `playerctl` | Previously required by [desktop services](../packaging/hyprland-desktop.spec). [Media key bindings](../defaults/hypr/bindings/media.lua) call `strata-shell media`; the [media service](../shell/plugins/services/media/Service.qml) uses Quickshell MPRIS directly. No shipped command invokes `playerctl`. | Approved and removed from default requirements. Personal scripts may still use its CLI. |
| `pavucontrol` | Previously required by desktop services. The [audio panel](../shell/plugins/panels/audio/Panel.qml) provides native controls. Its only runtime-source name match is an explanatory comment in the sound player; no launch action was found. | Approved and removed from default requirements. It can still be installed separately. This does not mean every Pavucontrol feature has an equivalent in Strata. |
| `fastfetch` | Required by desktop apps. Only a commented-out example in [the menu extension template](../defaults/strata/extensions/strata-menu.jsonc) launches it. | Optional information utility; removing the default requirement does not disable an active shipped action. |

“No caller found” applies to this repository's shipped setup, not every user's
environment. None of these findings alone justifies uninstalling host packages.

## Optional bundles and hardware choices

| Packages | Current use | Suggested choice |
| --- | --- | --- |
| `podman`, `podman-compose`, `toolbox` | Remain mandatory in desktop apps. The repository's [RPM builder](../bin/strata-build-rpms) invokes Podman. No active shipped runtime caller was found for Compose or Toolbox. | Consider an optional development/container bundle. Podman runs containers, Compose coordinates applications, and Toolbox provides development environments. Podman can remain a build prerequisite without being a desktop runtime requirement. |
| `buildah`, `skopeo` | No active shipped runtime caller was found. Buildah builds images; Skopeo handles image transfer/inspection. | Approved and removed from default requirements. They can still be installed separately; this does not exclude them from other packages' transitive dependencies. |
| `alsa-utils` | Mandatory desktop service dependency; no shipped `amixer`, `aplay`, or `alsactl` caller was found. Audio controls use PipeWire/Pulse interfaces. | Candidate for optional hardware diagnostics. Check Fedora service/transitive requirements before dropping it; absence of CLI calls does not prove its entire payload is unused. |
| `bolt` | Mandatory desktop services dependency; no Strata `boltctl` caller was found. | Hardware-specific Thunderbolt support. Keep for supported hardware or make optional; it is a daemon package, so missing CLI calls are not proof of redundancy. |
| `usbutils`, `unzip` | Core requirements; no shipped `lsusb` or `unzip` invocation was found. | Convenience/diagnostic tools rather than demonstrated shell runtime requirements. Consider moving out of core. |
| `fcitx5-unikey` | Vietnamese engine supported by the [language-input panel](../shell/plugins/language-input/Panel.qml), mandatory in config. | Language preference, not a duplicate. Could become a language option while retaining Fcitx itself. |
| `gvfs-mtp`, `gvfs-smb`, `gvfs-nfs` | Desktop services add phone and network-share capabilities through GVfs. | Optional capability choices. Removing them reduces supported locations in the file manager. |
| `file-roller`, `gnome-disk-utility`, `sushi`, `flatpak` | Applications/integration tools intentionally selected by desktop apps. They need not be launched by Strata scripts to be useful. | Product decisions, not demonstrated dead dependencies. Archive management, disk administration, file preview, and app distribution are distinct functions. |

## Overlap that is currently used

| Packages/features | Why both currently exist | Effect of consolidation |
| --- | --- | --- |
| Strata Snip + `imv` | [strata-default-files](../bin/strata-default-files) first assigns all image MIME types to Imv, then overrides the editor's advertised types with Strata Snip. [Imv shortcuts](../config/imv/config) also call Strata rotate/convert tools. | Imv is still the fallback association for remaining image types. Removing it requires revising the defaults command and deciding how to handle those formats. |
| Native Bluetooth panel + `blueman` | The panel's gear button defaults to `blueman-manager`; see [Panel.qml](../shell/plugins/panels/bluetooth/Panel.qml) and its manifest. | Removing Blueman leaves the default settings action broken unless that action is hidden/replaced. |
| Native network panel + `nm-connection-editor` | The panel's settings action explicitly defaults to this program in [Panel.qml](../shell/plugins/panels/network/Panel.qml). | Keep for advanced connection editing or replace the action and its capabilities first. |
| Native idle service + `hypridle` | [Autostart](../defaults/hypr/autostart.lua) starts Hypridle. [Its configuration](../config/hypr/hypridle.conf) retains before/after-sleep hooks, while Strata handles timers. | Removing it requires moving the sleep hooks into another component. It is not equivalent to unused Hyprlock. |
| `grim` / `slurp` / `hyprpicker` + Strata Snip | Capture helpers retain fallback/region selection paths. Hyprpicker also implements the color picker and screen freeze. | Keep unless those paths are deliberately retired; Snip does not make every capture utility obsolete. |
| `wf-recorder` + optional GPU screen recorder | [strata-capture-screenrecording](../bin/strata-capture-screenrecording) implements both paths; Fedora's declared default includes Wf-recorder. | Active fallback/default, not dead code. Optional GPU support does not justify removing it. |
| `ImageMagick`, `ffmpegthumbnailer`, Qt image support | ImageMagick now performs image probing/conversion/cropping and picker thumbnails. Ffmpegthumbnailer still generates video previews in the image menu, image picker, and lock poster. Qt image plugins render supported formats in the UI. | Different stages and media types. Keep; the libvips command dependency was already removed in the preceding migration. |
| `ffmpeg-free`, `libavcodec-freeworld`, GStreamer plugins | FFmpeg is used by capture/media casting; casting backends also use GStreamer. The casting spec explicitly adds the codec package. | Multiple media stacks, but currently selected backends consume them. Codec availability and Fedora/RPM Fusion dependency resolution need a fresh build/install check before consolidation. |
| `celluloid` + shipped `mpv.conf` | Video associations and completion notifications launch Celluloid. A standalone Mpv config is installed, but no active Strata `mpv` launch was found in the searched runtime sources. | Celluloid is used. The standalone Mpv config is a candidate for later file cleanup; its presence is not evidence that the `mpv` CLI must be a runtime dependency. |
| Zen + Chromium | Zen is the desktop browser choice; [strata-launch-webapp](../bin/strata-launch-webapp) explicitly uses Chromium for web apps. | To ship one browser, revise the web-app implementation/default choice first. |
| Waycast + Doubletake + Strata Cast | [Casting package descriptions](../packaging/strata-config.spec) distinguish Miracast, AirPlay screen mirroring/extension, and media casting to DLNA/Google Cast/AirPlay. | Potential optional casting bundle, not three identical implementations. Config currently requires the whole bundle, so installing config alone still installs all backends. |

## Complementary packages to retain

| Group | Evidence or purpose |
| --- | --- |
| Hyprland, GUI utilities, UWSM, greetd, Quickshell, Ghostty | Compositor/session/login/shell/terminal roles. Greeter and session lock operate at different stages, even though they share UI components. |
| `xdg-desktop-portal`, Hyprland backend, GTK backend | [Portal configuration](../config/xdg-desktop-portal/hyprland-portals.conf) explicitly selects GTK for file/app chooser and Hyprland as preferred backend. The `-hyprland-upstream` dependency is a versioned **provide** from the same Hyprland backend RPM, not another portal process/package to remove. |
| PipeWire, PipeWire-Pulse, WirePlumber, `pipewire-utils`, `pulseaudio-utils` | Media graph, Pulse compatibility, session policy, and CLI controls. [System sounds](../shell/plugins/services/system-sounds/bin/strata-sounds) use `pw-play` with `paplay` fallback. Screen capture and application routing also rely on this stack. |
| `gnome-keyring`, `gnome-keyring-pam`, `libsecret`, PAM, Polkit, `strata-lock-auth` | Secret storage, login unlock, client API, authentication, privilege authorization, and Strata lock authentication serve separate roles. |
| `wl-clipboard`, `cliphist`, `wtype` | Clipboard transport, history, and synthetic input. [Clipboard paste helpers](../bin/strata-clipboard-send-paste) and emoji insertion still use Wtype. |
| `inotify-tools`, `socat`, `jq` | Plugin live watching explicitly invokes `inotifywait` in [PluginRegistry.qml](../shell/services/PluginRegistry.qml); IPC and JSON helpers use the other tools. |
| `xrandr`, XWayland | [strata-set-primary-monitor](../bin/strata-set-primary-monitor) sets XWayland's primary output; autostart and layout saves call it. A Wayland session still has this explicit compatibility path. |
| `hyprsunset`, `hyprpicker`, `hyprcursor`, `hyprlang` | Nightlight backend, color/capture tools, cursor support, and theme utility support. They are not replaced by the QML controls that invoke them. |
| `brightnessctl`, `ddcutil`, UPower, power-profiles-daemon | Internal brightness, external monitor DDC control, battery reporting, and power policy have different hardware roles. |
| Fcitx core, GTK/Qt integration, config tool | Input engine, toolkit integrations, and the panel's explicit settings action. |
| `zenity`, `tesseract` + English data, `gjs` + AT-SPI | Image helpers still open Zenity dialogs; native capture invokes Tesseract OCR; [strata-app-actions](../bin/strata-app-actions) uses GJS/AT-SPI and is called by the menu. |
| Fonts, Yaru icons, Qt SVG/image plugins, layer-shell-qt | Rendering/assets/platform integration. Fonts with CJK/emoji coverage complement the primary font; image decoders and icon assets are not interchangeable. |
| NetworkManager/Wi-Fi, Avahi/NSS mDNS, BlueZ, GVfs/UDisks/Udiskie | Connectivity, discovery, Bluetooth, and storage integration. Udiskie is explicitly autostarted. |
| `dnsmasq`, `iw`, `nftables`, firewalld, `wpa_supplicant`, `iproute` | Hotspot/casting/network administration capabilities. Consolidation needs a feature-specific audit, not a blanket removal based on multiple networking tools. |
| `btop`, Nautilus, Neovim | Active system-monitor action and selected file/text applications. Btop has theme integration and a default key binding. |
| Python, Perl modules, LuaJIT, shell and base CLI tools | Shipped helpers still use these interpreters/utilities. The ImageMagick migration did not remove every Python helper. `xkbcli` from `libxkbcommon-utils` is used by shortcut-guide/keyboard services. |
| `libnotify`, `qrencode` | `notify-send` clients complement the native notification server; Wi-Fi QR generation explicitly invokes Qrencode. |

## Duplicate dependency declarations

Several package names appear in multiple `Requires` lists. This does **not**
install multiple copies; DNF resolves a shared package once.

- Core already requires Ghostty, Quickshell, primary/CJK/emoji fonts, and Tar;
  config also explicitly requires these.
- Services already requires GNOME Keyring/PAM integration, NetworkManager-Wi-Fi,
  UPower, Jq, and Socat; config repeats these.
- Rsync is required by both core and apps.
- Casting subpackages repeat GStreamer, portal, networking, and audio requirements
  where each independently installable backend needs them. These repetitions
  protect standalone backend installs and should not be removed simply for style.
- A command used in both build checks and runtime may legitimately appear under
  both `BuildRequires` and `Requires`. Build-only compiler/development packages
  are not a default installed desktop package set.

Removing inherited declarations is optional spec maintenance, with no expected
installed-size benefit. Explicit requirements also document direct consumers.
Do not remove version constraints unless another dependency preserves the needed
minimum version.

## Decisions to make before changing packages

1. Hyprlock, Playerctl, and Pavucontrol: default requirements removed. Decide separately whether to remove Fastfetch.
2. Make container/development tools an optional bundle?
3. Keep all casting backends mandatory, or make casting an optional install?
4. Keep diagnostic/hardware tools in core, or move them into optional choices?
5. Keep Imv as the broader-format fallback and external Bluetooth/network settings?

For any approved removals, update all relevant dependency edges and launch/default
actions, then test the resulting RPM transaction in a fresh Fedora environment.
Source preparation and the existing public RPM repository are at different
stages: the rebuilt 1.0.0 packages are still to be produced by the user. This
report describes source intent, not the contents of old published RPMs.

## Direct runtime dependency inventory

This inventory includes explicit `Requires` declarations in the original five specs,
plus the restored lock-auth spec below.
RPM macros and version constraints are kept as written; automatically generated
library dependencies are outside this inventory. `BuildRequires` are excluded.

### strata-lock-auth.spec

**strata-lock-auth**: `pam`. Release CI now builds this policy package from source.

### hyprland-desktop.spec

**hyprland-desktop**: `%{name}-core = 1:%{version}-%{release}`, `%{name}-services = 1:%{version}-%{release}`, `%{name}-apps = 1:%{version}-%{release}`, `zen-browser >= %{zen_version}`.

**hyprland-desktop-core**: `hyprland = 0.56.2-2.fc44`, `hyprland-guiutils = 0.56.2-2.fc44`, `uwsm >= 0.27.0`, `ghostty >= 1.3.1`, `jetbrains-mono-nerd-fonts >= 3.5.1`, `google-noto-sans-cjk-fonts`, `google-noto-emoji-color-fonts`, `greetd`, `greetd-selinux`, `quickshell >= 0.3.1`, `xdg-utils`, `zsh`, `rsync`, `tar`, `unzip`, `usbutils`.

**hyprland-desktop-services**: `NetworkManager`, `NetworkManager-wifi`, `avahi`, `nss-mdns`, `wireless-regdb`, `pipewire`, `pipewire-pulseaudio`, `wireplumber`, `alsa-utils`, `bluez`, `blueman`, `brightnessctl`, `power-profiles-daemon`, `upower`, `ddcutil`, `bolt`, `xdg-desktop-portal`, `xdg-desktop-portal-hyprland-upstream >= 1.4.1`, `xdg-desktop-portal-gtk`, `wl-clipboard`, `grim`, `slurp`, `wtype`, `libnotify`, `socat`, `jq`, `inotify-tools`, `gnome-keyring`, `gnome-keyring-pam`, `libsecret`, `gvfs`, `gvfs-mtp`, `gvfs-smb`, `gvfs-nfs`, `udisks2`, `udiskie`, `xdg-user-dirs`.

**hyprland-desktop-apps**: `chromium`, `nautilus`, `file-roller`, `gnome-disk-utility`, `sushi`, `podman`, `podman-compose`, `toolbox`, `flatpak`, `fastfetch`, `btop`, `rsync`.

**uwsm**: `python3-dbus`, `python3-pyxdg`, `systemd`, `util-linux`.

**ghostty**: no explicit runtime `Requires` (generated dependencies may apply).

**zen-browser**: `alsa-lib`, `gtk3`, `libXtst`, `mesa-libgbm`, `nss`.

### hyprland-minimal.spec

**hyprland**: `xorg-x11-server-Xwayland`.

**hyprland-guiutils**: `%{name}%{?_isa} = %{version}-%{release}`.

**xdg-desktop-portal-hyprland**: `%{name}%{?_isa} = %{version}-%{release}`, `pipewire`, `qt6-qtbase-gui`, `xdg-desktop-portal`.

### hyprland-utilities.spec

**hyprland-utilities**: `hypridle%{?_isa} = %{hypridle_version}-%{release}`, `hyprsunset%{?_isa} = %{hyprsunset_version}-%{release}`, `hyprpicker%{?_isa} = %{hyprpicker_version}-%{release}`, `hyprcursor >= 0.1.11`, `hyprlang`.

**hypridle**: `hyprland%{?_isa} = %{hyprland_version}-%{hyprland_release}%{?dist}`.

**hyprsunset**: `hyprland%{?_isa} = %{hyprland_version}-%{hyprland_release}%{?dist}`.

**hyprpicker**: `hyprland%{?_isa} = %{hyprland_version}-%{hyprland_release}%{?dist}`.

### jetbrains-mono-nerd-fonts.spec

**jetbrains-mono-nerd-fonts**: no explicit runtime `Requires` (generated dependencies may apply).

### strata-config.spec

**strata-config**: `hyprland-desktop-core`, `hyprland-desktop-services`, `ghostty`, `nautilus`, `neovim`, `quickshell >= 0.3.1`, `layer-shell-qt`, `cliphist >= 0.7.0`, `hypridle`, `hyprsunset`, `hyprpicker`, `hyprcursor >= 0.1.11`, `hyprlang`, `libevdev`, `python3`, `dnf5`, `rpm`, `sudo`, `wf-recorder`, `pipewire-utils`, `pulseaudio-utils`, `pam`, `gnome-keyring`, `gnome-keyring-pam`, `strata-lock-auth`, `fcitx5`, `fcitx5-gtk`, `fcitx5-qt`, `fcitx5-configtool`, `fcitx5-unikey`, `ImageMagick`, `gawk`, `libxkbcommon-utils`, `luajit`, `ffmpegthumbnailer`, `gum`, `nm-connection-editor`, `dnsmasq`, `iw`, `NetworkManager-wifi`, `nftables`, `curl`, `file`, `desktop-file-utils`, `git-core`, `tar`, `jq`, `socat`, `xrandr`, `perl(Encode)`, `perl(Fcntl)`, `perl(IO::Handle)`, `imv`, `ffmpeg-free`, `celluloid`, `strata-casting = 1:%{version}-%{release}`, `zenity`, `util-linux-core`, `qt6-qtimageformats`, `qt6-qtsvg`, `tesseract`, `tesseract-langpack-eng`, `upower`, `findutils`, `coreutils`, `glib2`, `gjs`, `at-spi2-core`, `polkit`, `qrencode`, `jetbrains-mono-nerd-fonts`, `google-noto-sans-cjk-fonts`, `google-noto-emoji-color-fonts`, `yaru-icon-theme`.

**strata-casting**: `strata-waycast = 1:%{version}-%{release}`, `strata-doubletake = 1:%{version}-%{release}`, `strata-cast = 1:%{version}-%{release}`.

**strata-waycast**: `firewalld`, `NetworkManager-wifi`, `wpa_supplicant`, `dnsmasq`, `iw`, `iproute`, `polkit`, `gstreamer1-plugins-base`, `gstreamer1-plugins-good`, `gstreamer1-plugins-bad-free`, `gstreamer1-plugin-openh264`, `gstreamer1-plugins-ugly`, `gstreamer1`, `pipewire-gstreamer`, `xdg-desktop-portal-hyprland`, `perl(IO::Socket::UNIX)`.

**strata-doubletake**: `gstreamer1-plugins-base`, `gstreamer1-plugins-good`, `gstreamer1-plugins-bad-free`, `gstreamer1-plugin-openh264`, `gstreamer1`, `pipewire-gstreamer`, `pulseaudio-utils`, `xdg-desktop-portal-hyprland`.

**strata-cast**: `strata-waycast = 1:%{version}-%{release}`, `ffmpeg-free`, `libavcodec-freeworld`, `firewalld`, `polkit`, `iproute`, `systemd`.
