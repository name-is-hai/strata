Name:           strata-config
Version:        4.0.0~alpha
Release:        2%{?dist}
Summary:        Desktop configuration defaults for Strata

License:        MIT AND LicenseRef-Win11OSX
URL:            https://github.com/name-is-hai/strata
Source0:        %{name}-%{version}.tar.gz

ExclusiveArch:   x86_64
BuildRequires:    cmake
BuildRequires:    gcc-c++
BuildRequires:    ninja-build
BuildRequires:    pkgconf-pkg-config
BuildRequires:    qt6-qtbase-devel >= 6.8
BuildRequires:    layer-shell-qt-devel
BuildRequires:    wayland-devel
BuildRequires:    wayland-protocols-devel
BuildRequires:    libdeflate-devel
BuildRequires:    libevdev-devel
BuildRequires:    python3
BuildRequires:    jq
BuildRequires:    socat

Requires:       hyprland-desktop-core
Requires:       hyprland-desktop-services
Requires:       ghostty
Requires:       nautilus
Requires:       neovim
Requires:       quickshell >= 0.3.1
Requires:       layer-shell-qt
Requires:       cliphist >= 0.7.0
Requires:       hypridle
Requires:       hyprlock
Requires:       hyprsunset
Requires:       hyprpicker
Requires:       hyprcursor >= 0.1.11
# Private Hyprland SONAME provides cannot serve the public theme utility.
Requires:       hyprlang
Requires:       libevdev
Requires:       python3
Requires:       dnf5
Requires:       rpm
Requires:       sudo
Requires:       wf-recorder
Requires:       pipewire-utils
Requires:       pulseaudio-utils
Requires:       pam
Requires:       gnome-keyring
Requires:       gnome-keyring-pam
Requires:       strata-lock-auth
Requires:       fcitx5
Requires:       fcitx5-gtk
Requires:       fcitx5-qt
Requires:       fcitx5-configtool
Requires:       fcitx5-unikey
Requires:       vips-tools
Requires:       ImageMagick
Requires:       gawk
Requires:       libxkbcommon-utils
Requires:       luajit
Requires:       ffmpegthumbnailer
Requires:       gum
Requires:       nm-connection-editor
Requires:       dnsmasq
Requires:       iw
Requires:       NetworkManager-wifi
Requires:       nftables
Requires:       curl
Requires:       file
Requires:       desktop-file-utils
Requires:       git-core
Requires:       tar
Requires:       jq
Requires:       socat
Requires:       xrandr
Requires:       perl(Encode)
Requires:       perl(Fcntl)
Requires:       perl(IO::Handle)
Requires:       imv
Requires:       ffmpeg-free
Requires:       celluloid
Requires:       strata-casting
Requires:       zenity
Requires:       util-linux-core
Requires:       qt6-qtimageformats
Requires:       qt6-qtsvg
Requires:       tesseract
Requires:       tesseract-langpack-eng
Requires:       upower
Requires:       findutils
Requires:       coreutils
Requires:       glib2
Requires:       gjs
Requires:       at-spi2-core
Requires:       polkit
Requires:       qrencode
Requires:       jetbrains-mono-nerd-fonts
Requires:       google-noto-sans-cjk-fonts
Requires:       google-noto-emoji-color-fonts
Requires:       yaru-icon-theme

%description
Versioned Hyprland, Quickshell, UWSM and portal defaults for Strata.
RPM-owned defaults remain under /usr/share while a small set of
Strata-specific user entry files is installed only when explicitly requested.
Personal application configuration belongs in the separate dotfiles repository.

%prep
%autosetup

%build
g++ %{optflags} -std=c++17 native/strata-font-ink.cpp $(pkg-config --cflags --libs Qt6Gui) -o strata-font-ink
gcc %{optflags} -std=c11 native/strata-mouse-hid-battery.c -o strata-mouse-hid-battery
gcc %{optflags} -std=c11 third_party/wiggle/scripts/wiggle-monitor.c \
    $(pkg-config --cflags --libs libevdev) -lm -o strata-wiggle-monitor
cmake -S third_party/strata-snip -B strata-snip-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX=%{_prefix}
cmake --build strata-snip-build --parallel

%install
DESTDIR=%{buildroot} cmake --install strata-snip-build
install -Dpm 0755 strata-font-ink %{buildroot}%{_bindir}/strata-font-ink
install -Dpm 0755 strata-mouse-hid-battery %{buildroot}%{_bindir}/strata-mouse-hid-battery
install -Dpm 0755 strata-wiggle-monitor %{buildroot}%{_bindir}/strata-wiggle-monitor
install -Dpm 0755 third_party/wiggle/scripts/wiggle-discover-cursor %{buildroot}%{_bindir}/strata-wiggle-discover-cursor
install -Dpm 0644 default/udev/70-strata-wiggle.rules %{buildroot}%{_prefix}/lib/udev/rules.d/70-strata-wiggle.rules
install -Dpm 0644 default/udev/60-strata-mouse-battery.rules \
    %{buildroot}%{_prefix}/lib/udev/rules.d/60-strata-mouse-battery.rules

install -d %{buildroot}%{_datadir}/strata/user-config
cp -a config/hypr config/uwsm config/xdg-desktop-portal config/gtk-3.0 config/gtk-4.0 config/imv \
    %{buildroot}%{_datadir}/strata/user-config/

install -d %{buildroot}%{_datadir}/icons
cp -a default/icons/Win11OSX %{buildroot}%{_datadir}/icons/

install -d %{buildroot}%{_datadir}/strata/default
cp -a default/. %{buildroot}%{_datadir}/strata/default/

install -d %{buildroot}%{_datadir}/strata/config
cp -a runtime-config/. %{buildroot}%{_datadir}/strata/config/

install -Dpm 0644 systemd/strata-stay-awake.service \
    %{buildroot}%{_prefix}/lib/systemd/user/strata-stay-awake.service
install -d %{buildroot}%{_datadir}/strata/greeter
install -Dpm 0644 default/greeter/shell.qml \
    %{buildroot}%{_datadir}/strata/greeter/shell.qml
install -Dpm 0644 default/greeter/hyprland.lua \
    %{buildroot}%{_datadir}/strata/greeter/hyprland.lua
install -Dpm 0644 default/greeter/config.toml \
    %{buildroot}%{_datadir}/strata/greeter/config.toml
install -Dpm 0644 default/greeter/theme.conf \
    %{buildroot}%{_datadir}/strata/greeter/theme.conf
ln -s ../shell/Commons %{buildroot}%{_datadir}/strata/greeter/Commons
ln -s ../shell/Ui %{buildroot}%{_datadir}/strata/greeter/Ui
install -Dpm 0644 themes/lawson-night/backgrounds/wallhaven-1k6ljv.jpg \
    %{buildroot}%{_datadir}/strata/greeter/background.jpg
install -Dpm 0644 default/fontconfig/66-strata-jetbrains-mono-nerd.conf \
    %{buildroot}%{_sysconfdir}/fonts/conf.d/66-strata-jetbrains-mono-nerd.conf
install -Dpm 0644 default/mpv/mpv.conf \
    %{buildroot}%{_sysconfdir}/mpv/mpv.conf
install -Dpm 0644 default/polkit-1/rules.d/49-strata-greeter.rules \
    %{buildroot}%{_sysconfdir}/polkit-1/rules.d/49-strata-greeter.rules

cp -a bin shell themes docs %{buildroot}%{_datadir}/strata/
find %{buildroot}%{_datadir}/strata -type f -name '*.pyc' -delete
find %{buildroot}%{_datadir}/strata -depth -type d -name '__pycache__' -empty -delete
install -Dpm 0644 default/applications/strata-editor.desktop \
    %{buildroot}%{_datadir}/applications/strata-editor.desktop
install -Dpm 0644 default/applications/strata-image-editor.desktop \
    %{buildroot}%{_datadir}/applications/strata-image-editor.desktop
cp -a runtime-version %{buildroot}%{_datadir}/strata/version

install -d %{buildroot}%{_datadir}/quickshell/strata
cp -al %{buildroot}%{_datadir}/strata/shell/. \
    %{buildroot}%{_datadir}/quickshell/strata/

for script in bin/strata-*; do
    install -Dpm 0755 "$script" %{buildroot}%{_bindir}/"$(basename "$script")"
done

%files
%license default/icons/Win11OSX/LICENSE.txt
%license LICENSE third_party/wiggle/LICENSE shell/plugins/services/media/MEDIA-CONTROL-LICENSE shell/plugins/panels/wireless-display/LICENSE shell/plugins/panels/cast/LICENSE
%license shell/plugins/services/keyboard-osd/KEYGLOW-LICENSE shell/plugins/services/keyboard-osd/LOCK-KEYS-LICENSE
%license shell/plugins/services/shortcut-guide/LICENSE
%license shell/plugins/services/shortcut-guide/KEY-PROMOTER-LICENSE
%license shell/plugins/notifications/center/LICENSE shell/plugins/notifications/center/LICENSE-LUCIDE shell/plugins/notifications/center/LICENSE-OMARCHY
%license shell/plugins/theme-picker/LICENSE
%doc docs/strata-config.md
%{_bindir}/strata-*
%{_prefix}/lib/udev/rules.d/60-strata-mouse-battery.rules
%{_prefix}/lib/udev/rules.d/70-strata-wiggle.rules
%{_datadir}/applications/strata-snip.desktop
%{_datadir}/applications/strata-editor.desktop
%{_datadir}/applications/strata-image-editor.desktop
%license %{_datadir}/licenses/strata-snip/
%{_prefix}/lib/systemd/user/strata-stay-awake.service
%config(noreplace) %{_sysconfdir}/fonts/conf.d/66-strata-jetbrains-mono-nerd.conf
%config(noreplace) %{_sysconfdir}/mpv/mpv.conf
%config(noreplace) %{_sysconfdir}/polkit-1/rules.d/49-strata-greeter.rules
%{_datadir}/icons/Win11OSX/
%{_datadir}/strata/
%{_datadir}/quickshell/strata/

%changelog
* Sat Oct 17 2026 Strata Maintainers <maintainers@strata.dev> - 4.0.0~alpha-2
- Exclude generated Python caches from the installed source tree

* Sat Oct 17 2026 Strata Maintainers <maintainers@strata.dev> - 4.0.0~alpha-1
- Align the package version with the Strata alpha release and package greeter QML links

* Mon Oct 12 2026 Strata Maintainers <maintainers@strata.dev> - 0.1.202-1
- Open saved screenshots in Omasnap when their notification is clicked

* Mon Oct 12 2026 Strata Maintainers <maintainers@strata.dev> - 0.1.201-1
- Show the saved Omasnap image and path in screenshot notifications

* Mon Oct 12 2026 Strata Maintainers <maintainers@strata.dev> - 0.1.200-1
- Build and install Omasnap with Strata for frozen screenshot selection

* Mon Oct 12 2026 Strata Maintainers <maintainers@strata.dev> - 0.1.199-1
- Use Omasnap's native frozen screenshot selection when it is installed

* Mon Oct 12 2026 Strata Maintainers <maintainers@strata.dev> - 0.1.198-1
- Remove the experimental screenshot overlay surface

* Mon Oct 12 2026 Strata Maintainers <maintainers@strata.dev> - 0.1.197-1
- Keep a click-through frozen frame visible while selecting a screenshot region

* Mon Oct 12 2026 Strata Maintainers <maintainers@strata.dev> - 0.1.196-1
- Freeze the screen before region screenshot selection so hover UI is captured

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.195-1
- Install each generated Strata palette as Btop's active theme

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.194-1
- Show the configured keyboard layout when Fcitx5 is inactive

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.193-1
- Normalize painted bar icon bounds across status glyphs

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.192-1
- Limit Bluetooth glyph normalization to the idle/on icon

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.191-1
- Normalize the painted Bluetooth bar glyph to neighbouring status icons

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.190-1
- Activate Fcitx5 after selecting an input method and report selection errors

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.189-1
- Remove the redundant Fcitx5 activation switch from Input Method

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.188-1
- Add Fcitx5 activation switch and direct configured-input selection

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.187-1
- Recognize XKB's Space scan code during Fcitx5 shortcut capture

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.186-1
- Route Space to Fcitx5 shortcut capture and clear released modifier keys

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.185-1
- Capture physical Space keys reported as unknown by Wayland during shortcut recording

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.184-1
- Read Fcitx5 shortcuts correctly from generated commented configuration

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.183-1
- Recognize Wayland left/right modifier keys during Fcitx5 shortcut capture

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.182-1
- Hide shortcut save until a capture exists and discard unsaved captures on close

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.181-1
- Capture and confirm Fcitx5 toggle shortcuts before saving them

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.180-1
- Preserve modifier presses while recording Fcitx5 toggle shortcuts

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.179-1
- Reset Fcitx5 shortcut capture when the input panel closes

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.178-1
- Capture Alt and other modifier shortcuts correctly for Fcitx5 toggling

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.177-1
- Add recorded Fcitx5 input-method toggle shortcuts to the bar panel

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.176-1
- Make the bar panel Fcitx5-only instead of duplicating XKB layout controls

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.175-1
- Add live Fcitx5 status, toggle, and configuration controls to Language & Input

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.174-1
- Fix loading the bar-anchored Language & Input panel

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.173-1
- Anchor Language & Input to the bar like Display Layout

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.172-1
- Use Fcitx5 native Wayland frontend for GTK applications

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.171-1
- Show the active Fcitx input language in the bar and open Language & Input from it

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.170-1
- Require Fcitx5, application input modules, and Vietnamese Unikey support

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.169-1
- Limit Language & Input to keyboard layouts and switching shortcuts

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.168-1
- Keep Language & Input display-language changes per-user only

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.167-1
- Add the Language & Input panel for layouts, input switching, and locales

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.166-1
- Authorize the restricted SDDM wallpaper helper for automatic theme sync

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.165-1
- Reload the replaced SDDM wallpaper instead of retaining its image cache

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.164-1
- Synchronize selected desktop backgrounds to the Strata SDDM greeter

* Mon Oct 12 2026 Liam <liam@strata.local> - 0.1.163-1
- Apply saved hotspot access rules within the initial privileged AP setup call

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.162-1
- Keep the hotspot bar icon visible as a direct control while inactive

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.161-1
- Emit tab-separated hotspot status fields so the Network panel recognizes active hotspots

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.160-1
- Clear a stale hotspot activation error once NetworkManager reports it active

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.159-1
- Refresh hotspot state while the Network panel is open so client controls appear promptly

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.158-1
- Dismiss the temporary hotspot setup form when the panel closes or hotspot starts

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.157-1
- Replace the duplicate hotspot header icon with named connected-device controls

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.156-1
- Add a persistent hotspot setup control and active hotspot bar status icon

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.155-1
- Add hotspot on/off control and allow-list mode for approved devices

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.154-1
- Add hotspot 5 GHz selection and connected-device disconnect and block controls

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.153-1
- Use a separate ap0 interface for hotspots so the active Wi-Fi connection stays online

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.152-1
- Require dnsmasq so NetworkManager shared Wi-Fi hotspots can assign client IP addresses

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.151-1
- Add NetworkManager Wi-Fi hotspot controls to the default network panel

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.150-1
- Allow a new explicit lock after Quickshell reports a stale unlocked secure state

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.149-1
- Match SDDM password and power control surfaces to the active Strata lock defaults

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.148-1
- Blur the system-readable active background in the Strata SDDM greeter

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.147-1
- Use the installed JetBrainsMono Nerd Font Mono family in the SDDM greeter

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.146-1
- Match the password-only SDDM greeter to the Strata lock clock and power controls

* Sun Oct 11 2026 Liam <liam@strata.local> - 0.1.145-1
- Make the Better Lock-inspired date, seconds clock, and power controls the Strata lock default

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.144-1
- Keep the UWSM-managed Hyprland session as Strata's SDDM default

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.143-1
- Make Network Plus the default Wi-Fi panel with NetworkManager settings access
- Add Wi-Fi QR sharing and a live network speed test
- Require Polkit authentication before revealing a saved Wi-Fi password
- Fix the SDDM session selector with the Qt Quick Controls implementation
- Make SDDM password-only and always launch the UWSM-managed Hyprland session

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.142-1
- Add main, mirror, extend, on, and off actions to Display Layout

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.141-1
- Use the Omarchy carousel for Strata theme and background selection

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.140-1
- Write Ghostty settings to config.ghostty, its current preferred filename

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.139-1
- Reload Ghostty through its user service after a Strata theme update

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.138-1
- Restore Ghostty palette generation and synchronization with Strata themes

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.137-1
- Stop desktop themes from generating, selecting, or reloading Ghostty palettes

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.136-1
- Keep Clipboard, Emoji, and on-screen-display overlays from expanding at top-left

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.135-1
- Keep image-picker overlay geometry stable to match menu opening behavior

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.134-1
- Raise theme and background picker scrims above the bar like the main menu

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.133-1
- Use a compact adaptive image picker for themes and backgrounds

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.132-1
- Match the presentation terminal app ID with Hyprland regular-expression syntax

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.131-1
- Keep presentation terminals working when no custom logo asset is installed

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.130-1
- Float and center the Strata presentation terminal used by theme installation

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.129-1
- Add Omarchy-style guarded Git theme installation from the menu and Settings

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.128-1
- Apply a background selected from the menu, matching Omarchy's picker flow
- Require ffmpegthumbnailer for video background previews

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.127-1
- Stop applying desktop theme colors to browsers

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.126-1
- Skip the optional browser color refresh when its helper is unavailable

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.125-1
- Keep image pickers usable without vips-tools and require it for thumbnails

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.124-1
- Use the Omarchy-style image preview carousel for theme selection

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.123-1
- Apply a selected background on the first click

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.122-1
- Use jq for menu-selection JSON on minimal Fedora installations

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.121-1
- Add a menu picker for built-in and installed Strata themes

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.120-1
- Bundle the Castle on a Lake palette with an original Strata wallpaper

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.119-1
- Require Noto CJK and color emoji fonts for browser Unicode fallback

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.118-1
- Restore the stable shared baseline for bar icon glyphs

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.117-1
- Center bar icon glyphs by their painted bounds without changing their size

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.116-1
- Match the Bluetooth bar glyph to the surrounding status icon size

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.115-1
- Restore Omarchy bar icon proportions and smooth glyph rendering

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.114-1
- Restore the standard bar icon rendering and keep Bluetooth state correction local

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.113-1
- Normalize the painted size of all Nerd Font bar icons

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.112-1
- Optically match Bluetooth off and connected glyphs to the disconnected glyph

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.111-1
- Keep every Bluetooth state at the standard bar icon size

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.110-1
- Optically align the Bluetooth glyph with other bar icons

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.109-1
- Merge notification history and the notification service into one plugin

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.108-1
- Fit the battery percentage widget to its content

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.107-1
- Align battery percentage text with the other bar labels

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.106-1
- Document bar and indicator icon geometry in the default theme template

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.105-1
- Merge runtime defaults into the default source directory

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.104-1
- Keep runtime theme templates in one source directory

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.103-1
- Keep Display slider labels visible above their controls

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.102-1
- Show live brightness and text-size values in Display sliders

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.101-1
- Keep Display controls stable during monitor polling and use the standard scale presets

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.100-1
- Restore brightness and text-size controls in Display Layout

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.99-1
- Remove the Find My Mouse overlay and Ctrl bindings

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.98-1
- Make the double-Ctrl Find My Mouse gesture easier to trigger

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.97-1
- Bind Find My Mouse to the XKB Left and Right Ctrl codes

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.96-1
- Make JetBrains Mono Nerd Font Mono the default Strata monospace family

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.95-1
- Restore clock and workspace label scaling with the bar size

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.94-1
- Restore the default 16px bar icon canvas

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.93-1
- Restore the previous Lucide outline icons in the status bar

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.92-1
- Normalize filled status SVGs to a visible light foreground

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.91-1
- Use filled status-bar SVGs for system controls

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.90-1
- Keep bar text at its configured size when compacting status icons

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.89-1
- Match the bar icon canvas to the compact menu icon scale

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.88-1
- Combine notification history and its bar bell into one plugin

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.87-1
- Export the shared SVG icon component to bar widgets

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.86-1
- Render Lucide SVG strokes in a Qt-compatible visible color

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.85-1
- Use Hyprland Ctrl key codes for Find My Mouse bindings

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.84-1
- Convert remaining built-in status indicators to Lucide SVGs

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.83-1
- Replace status-bar icon glyphs with Lucide SVGs

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.82-1
- Add Find My Mouse, triggered by a double Ctrl press

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.81-1
- Draw Bluetooth and Do Not Disturb slashes over fixed-size glyphs

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.80-1
- Add the Strata Settings hub with a dedicated bar gear

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.79-1
- Normalize Bluetooth, Wi-Fi, and audio bar glyph sizes

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.78-1
+- Align notification bell icon optically with standard bar icon buttons

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.77-1
- Keep status indicators and move only Do Not Disturb to the notification bell

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.76-1
- Replace the indicator group with notification bell state and a live-notification dot

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.75-1
- Put the notification bell beside the system tray

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.74-1
- Expose the notification bell in the bar indicator picker

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.73-1
- Add a persistent notification bell to the bar

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.72-1
- Add a right-side notification history slide-over and Super+Period shortcut

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.71-1
- Put selected-monitor scale and refresh controls below the layout canvas
- Remove redundant monitor tabs

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.70-1
- Remove conflicting automatic scale rules when applying a monitor scale
- Always show the selected monitor's current refresh rate

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.69-1
- Add per-monitor refresh controls and monitor-local workspace cycling
- Correctly replace automatic scale rules for laptop displays

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.68-1
- Add per-monitor scale controls to the Display Layout editor

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.67-1
- Add per-monitor tabs to the Display Layout editor

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.66-1
- Poll Hyprland monitor state so display hotplug is detected on all drivers

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.65-1
- Replace the Display popup with a draggable display layout editor

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.64-1
- Apply resolution-preserving AC and battery refresh profiles to each display

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.63-1
- Apply automatic preferred-mode monitor rules to every connected output
- Keep display state refreshed while the Display popup is closed

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.62-1
- Set default status indicator glyphs to 80 percent of the bar icon canvas

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.61-1
- Keep the default 16px status indicators independent of desktop text size

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.60-1
- Remove the Bar Icon Size setting

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.59-1
- Add a persistent Dark Mode control to Display settings
- Let Bar Icon Size reach 28px and scale status indicators and tray icons

* Fri Oct 09 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.53-1
- Use the SDDM ComboBox index property for session selection

* Fri Oct 09 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.52-1
- Match the SDDM greeter to the Strata lock-screen palette and layout

* Fri Oct 09 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.51-1
- Use SDDM ComboBox's index property for session selection

* Fri Oct 09 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.50-1
- Let the dedicated strata-lock-auth package own the PAM lock policy

* Fri Oct 09 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.49-1
- Add the Strata SDDM theme using the desktop's login palette and typography

* Fri Oct 09 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.48-1
- Move weather, globe, Wi-Fi QR, and reminders out of the base desktop;
  they will be delivered by a separate plugin repository

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.47-1
- Move into the unified Strata repository
- Stop packaging personal dotfiles; package only Strata desktop entry files

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.46-1
- Own the Strata lock PAM policy with the rest of the desktop configuration

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.45-1
- Make Stay Awake inhibit the full hypridle and suspend chain
- Bind screen recording to Super+Shift+R instead of Alt+Print

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.44-1
- Require Neovim for the Hyprland configuration menu action

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.43-1
- Keep shell/ as the single Quickshell source tree
- Generate the compatibility install tree with space-efficient hard links

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.42-1
- Remove the screensaver and lock directly after the configured idle timeout
- Simplify idle status, controls, and packaging around lock-only behavior

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.41-1
- Keep all screen-recording menu levels at the larger capture width

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.40-1
- Add working desktop-audio plus microphone recording to the Fedora backend

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.39-1
- Ask whether to record a selected area or the full focused monitor

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.38-1
- Fix the Fedora recorder fallback so it opens the smart capture picker

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.37-1
- Show active desktop recording and PipeWire screen-sharing status in the bar
- Restore the Omarchy-style recording choices and smart monitor/region picker

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.36-1
- Probe both supported screen recorder backends without a shell wrapper

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.35-1
- Avoid polling the recorder process from the panel

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.34-1
- Fix screen-recording and Stay Awake indicator state refreshes
- Use Ghostty directly for Strata terminal helpers

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.33-1
- Run the installed Strata DNS helper during privilege elevation

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.32-1
- Add portable user defaults for Neovim, Zsh, Starship, Git, Fcitx5, Tmux, and Zed

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.31-1
- Remove 208 unreachable inherited commands from the packaged Strata runtime

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.30-1
- Restore display power after the compositor settles on resume

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.29-1
- Restore display power-off and automatic suspend after idle
- Wake DPMS after the resume delay and keep the lock screen visible after wake

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.28-1
- Fade the Strata menu layer in place instead of using a directional transition

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.27-1
- Keep the hidden menu overlay fullscreen to prevent top-left surface growth

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.26-1
- Keep keybinding help quiet when the optional xkbcli resolver is unavailable

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.25-1
- Route desktop bindings and menu actions through canonical Strata commands
- Replace stale Quickshell IPC targets with current plugin IDs
- Add Fedora grim and wf-recorder fallbacks to the canonical capture commands
- Remove superseded prototype session and capture entry points

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.24-1
- Route the Super+slash launcher binding through the supported Strata menu command

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.23-1
- Bind the launcher to the physical slash key for layout-independent Super+/

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.22-1
- Move the application launcher binding from Alt+Space to Super+slash

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.21-1
- Stop launching MATE Polkit alongside Strata's native Polkit agent

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.20-1
- Require Quickshell 0.3.1 for the network panel API

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.19-1
- Remove unsupported PanelWindow property so the Background plugin loads

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.18-1
- Use the named Quickshell config in Strata launch, restart, and IPC scripts
- Start the shell through strata-launch-shell at Hyprland login

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.17-1
- Collapse Indicators to active slots and expand to all configured slots on hover

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.16-1
- Disable stale QML disk cache for Strata shell launches

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.15-1
- Report each configured indicator's loaded state and measured width

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.14-1
- Render each configured bar indicator once so hover width equals its slot count

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.13-1
- Report Indicators hover, alwaysShow, and effective settings in bar geometry

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.12-1
- Drive each indicators reveal from its exact owning bar-slot hover state
- Report per-slot hover and indicator reveal state in bar geometry diagnostics

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.11-1
- Size each indicators hover target to its configured indicator-slot count

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.10-1
- Replace overlapping indicator hover flags with one per-instance hover handler

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.9-1
- Derive each hidden indicators hover target from its rendered bar thickness

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.8-1
- Give each indicators widget its own hover target and reveal state

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.7-1
- Keep inactive indicator reveal state local to each bar widget instance

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.6-1
- Reveal inactive bar indicators from their configured left, center, or right section

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.5-1
- Rename the desktop, runtime, commands, and Quickshell namespace to Strata
- Add the direct Strata system-menu IPC endpoint used by SUPER+ESCAPE
- Flatten the source tree to bin/, shell/, runtime-config/, runtime-default/,
  themes/, docs/ and runtime-version instead of a runtime/strata wrapper

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.4-1
- Add the minimal Fedora-oriented Quickshell runtime
- Remove bundled AI, updater, Arch-only, and personal-service integrations
- Keep weather, globe, reminders, and Wi-Fi QR as inactive optional payloads

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.3-1
- Add native clipboard history, emoji picker, and notification center panels
- Replace the Mako notification daemon and Fuzzel fallback dependencies
- Start the cliphist Wayland clipboard watcher with the session

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.2-1
- Add native Quickshell panels for audio, Bluetooth, network, display, and power
- Back panel actions with Fedora desktop service command-line interfaces

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.1-1
- Add reusable toggle bindings for panels and persistent desktop features
- Make color picking and screen recording explicit toggle actions

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.0-1
- Create initial Hyprland and Ghostty defaults
- Add a non-destructive per-user configuration installer
- Add the first Quickshell bar, launcher, system menu and IPC interface
