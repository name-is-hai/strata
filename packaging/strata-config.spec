Name:           strata-config
# Preserve upgrades from the 4.0.0-alpha development packages.
Epoch:          1
Version:        1.0.0
Release:        1%{?dist}
Summary:        Desktop configuration defaults for Strata

License:        MIT AND LicenseRef-Win11OSX
URL:            https://github.com/name-is-hai/strata
Source0:        %{name}-%{version}.tar.gz
Source1:        https://github.com/alchemy/waycast/releases/download/v0.6.1/waycast-v0.6.1-linux-amd64.tar.gz
Source2:        https://github.com/alchemy/doubletake/releases/download/v0.4.0-alchemy.5/doubletake-v0.4.0-alchemy.5-linux-amd64.tar.gz

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
BuildRequires:    cargo >= 1.98
BuildRequires:    rust >= 1.98
BuildRequires:    systemd-rpm-macros
BuildRequires:    firewalld-filesystem
BuildRequires:    dbus-daemon

Requires:       hyprland-desktop-core
Requires:       hyprland-desktop-services
Requires:       ghostty
Requires:       nautilus
Requires:       neovim
Requires:       quickshell >= 0.3.1
Requires:       layer-shell-qt
Requires:       cliphist >= 0.7.0
Requires:       hypridle
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
Requires:       strata-casting = 1:%{version}-%{release}
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

%package -n strata-casting
Summary:        Wireless display and media casting backends for Strata
License:        MIT AND LGPL-3.0-only
Requires:       strata-waycast = 1:%{version}-%{release}
Requires:       strata-doubletake = 1:%{version}-%{release}
Requires:       strata-cast = 1:%{version}-%{release}

%description -n strata-casting
Backends for Strata's wireless display and media-casting panels.

%package -n strata-waycast
Summary:        Miracast with Fedora firewalld networking
License:        MIT
Requires:       firewalld
Requires:       NetworkManager-wifi
Requires:       wpa_supplicant
Requires:       dnsmasq
Requires:       iw
Requires:       iproute
Requires:       polkit
Requires:       gstreamer1-plugins-base
Requires:       gstreamer1-plugins-good
Requires:       gstreamer1-plugins-bad-free
Requires:       gstreamer1-plugin-openh264
Requires:       gstreamer1-plugins-ugly
Requires:       gstreamer1
Requires:       pipewire-gstreamer
Requires:       xdg-desktop-portal-hyprland
Requires:       perl(IO::Socket::UNIX)

%description -n strata-waycast
Waycast Miracast sender with Strata's session-scoped firewalld adapter.
The upstream release sender is checksum verified; its privileged networking
helper is built from the vendored source with the Fedora adaptation.

%package -n strata-doubletake
Summary:        AirPlay screen mirroring and extended desktops
License:        LGPL-3.0-only
Requires:       gstreamer1-plugins-base
Requires:       gstreamer1-plugins-good
Requires:       gstreamer1-plugins-bad-free
Requires:       gstreamer1-plugin-openh264
Requires:       gstreamer1
Requires:       pipewire-gstreamer
Requires:       pulseaudio-utils
Requires:       xdg-desktop-portal-hyprland

%description -n strata-doubletake
Pinned alchemy Doubletake AirPlay sender with per-receiver Mirror and
Extend modes. Receivers and encoder capabilities determine availability.

%package -n strata-cast
Summary:        Cast local media to DLNA, Google Cast and AirPlay receivers
License:        MIT
Requires:       strata-waycast = 1:%{version}-%{release}
Requires:       ffmpeg-free
Requires:       libavcodec-freeworld
Requires:       firewalld
Requires:       polkit
Requires:       iproute
Requires:       systemd

%description -n strata-cast
Strata's adaptation of UniCast, built from pinned source. The user daemon
starts on demand and uses runtime firewalld rules for the selected receiver.

%prep
%autosetup
printf 'af118d64e7f2d3cbab30806fd274b3d128e6c796e176a59b1d3e5a75a83e3a21  %%s\n' '%{SOURCE1}' | sha256sum -c -
printf 'ff60045c443c49e5b98810a42e7f35b2495fab54036eb16d187716899b66a1b2  %%s\n' '%{SOURCE2}' | sha256sum -c -
tar -xzf %{SOURCE1}
tar -xzf %{SOURCE2}

%build
g++ %{optflags} -std=c++17 native/strata-font-ink.cpp $(pkg-config --cflags --libs Qt6Gui) -o strata-font-ink
gcc %{optflags} -std=c11 third_party/wiggle/scripts/wiggle-monitor.c \
    $(pkg-config --cflags --libs libevdev) -lm -o strata-wiggle-monitor
cmake -S third_party/strata-snip -B strata-snip-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX=%{_prefix}
cmake --build strata-snip-build --parallel

# Cargo.lock files pin all crate versions. Build in the network-enabled Strata
# container; runtime machines require neither a compiler nor a Rust toolchain.
CARGO_TARGET_DIR="${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}" cargo build --release --locked --manifest-path third_party/waycast/Cargo.toml -p waycast-networkd
CARGO_TARGET_DIR="${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}" cargo build --release --locked --manifest-path third_party/strata-cast/Cargo.toml

%check
CARGO_TARGET_DIR="${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}" cargo test --locked --manifest-path third_party/waycast/Cargo.toml -p waycast-networkd --lib
CARGO_TARGET_DIR="${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}" cargo test --locked --manifest-path third_party/strata-cast/Cargo.toml

%install
DESTDIR=%{buildroot} cmake --install strata-snip-build
install -Dpm 0755 strata-font-ink %{buildroot}%{_bindir}/strata-font-ink
install -Dpm 0755 strata-wiggle-monitor %{buildroot}%{_bindir}/strata-wiggle-monitor
install -Dpm 0755 third_party/wiggle/scripts/wiggle-discover-cursor %{buildroot}%{_bindir}/strata-wiggle-discover-cursor
install -Dpm 0644 defaults/udev/70-strata-wiggle.rules %{buildroot}%{_prefix}/lib/udev/rules.d/70-strata-wiggle.rules

install -d %{buildroot}%{_datadir}/strata/user-config
cp -a config/hypr config/uwsm config/xdg-desktop-portal config/gtk-3.0 config/gtk-4.0 config/imv \
    %{buildroot}%{_datadir}/strata/user-config/

install -d %{buildroot}%{_datadir}/icons
cp -a defaults/icons/Win11OSX %{buildroot}%{_datadir}/icons/

install -d %{buildroot}%{_datadir}/strata/default
cp -a defaults/. %{buildroot}%{_datadir}/strata/default/

install -d %{buildroot}%{_datadir}/strata/config/strata
cp -a defaults/strata/shell.json defaults/strata/extensions defaults/strata/hooks \
    %{buildroot}%{_datadir}/strata/config/strata/

install -Dpm 0644 systemd/strata-stay-awake.service \
    %{buildroot}%{_prefix}/lib/systemd/user/strata-stay-awake.service
install -d %{buildroot}%{_datadir}/strata/greeter
install -Dpm 0644 defaults/greeter/shell.qml \
    %{buildroot}%{_datadir}/strata/greeter/shell.qml
install -Dpm 0644 defaults/greeter/hyprland.lua \
    %{buildroot}%{_datadir}/strata/greeter/hyprland.lua
install -Dpm 0644 defaults/greeter/config.toml \
    %{buildroot}%{_datadir}/strata/greeter/config.toml
install -Dpm 0644 defaults/greeter/theme.conf \
    %{buildroot}%{_datadir}/strata/greeter/theme.conf
ln -s ../shell/Commons %{buildroot}%{_datadir}/strata/greeter/Commons
ln -s ../shell/Ui %{buildroot}%{_datadir}/strata/greeter/Ui
install -Dpm 0644 themes/lawson-night/backgrounds/wallhaven-1k6ljv.jpg \
    %{buildroot}%{_datadir}/strata/greeter/background.jpg
install -Dpm 0644 defaults/fontconfig/66-strata-jetbrains-mono-nerd.conf \
    %{buildroot}%{_sysconfdir}/fonts/conf.d/66-strata-jetbrains-mono-nerd.conf
install -Dpm 0644 defaults/mpv/mpv.conf \
    %{buildroot}%{_sysconfdir}/mpv/mpv.conf
install -Dpm 0644 defaults/polkit-1/rules.d/49-strata-greeter.rules \
    %{buildroot}%{_sysconfdir}/polkit-1/rules.d/49-strata-greeter.rules

cp -a bin shell themes docs %{buildroot}%{_datadir}/strata/
find %{buildroot}%{_datadir}/strata -type f -name '*.pyc' -delete
find %{buildroot}%{_datadir}/strata -depth -type d -name '__pycache__' -empty -delete
install -Dpm 0644 defaults/applications/strata-editor.desktop \
    %{buildroot}%{_datadir}/applications/strata-editor.desktop
install -Dpm 0644 defaults/applications/strata-image-editor.desktop \
    %{buildroot}%{_datadir}/applications/strata-image-editor.desktop
cp -a runtime-version %{buildroot}%{_datadir}/strata/version

install -d %{buildroot}%{_datadir}/quickshell/strata
cp -al %{buildroot}%{_datadir}/strata/shell/. \
    %{buildroot}%{_datadir}/quickshell/strata/

for script in bin/strata-*; do
    install -Dpm 0755 "$script" %{buildroot}%{_bindir}/"$(basename "$script")"
done

install -Dpm755 waycast-v0.6.1-linux-amd64/waycast %{buildroot}%{_bindir}/waycast
install -Dpm755 "${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}/release/waycast-networkd" %{buildroot}%{_libexecdir}/strata-waycast-networkd
install -Dpm755 doubletake-v0.4.0-alchemy.5-linux-amd64/doubletake %{buildroot}%{_bindir}/doubletake
install -Dpm755 doubletake-v0.4.0-alchemy.5-linux-amd64/doubletake-ctl %{buildroot}%{_bindir}/doubletake-ctl
install -Dpm755 "${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}/release/strata-castd" %{buildroot}%{_bindir}/strata-castd
install -Dpm644 packaging/casting/strata-castd.service %{buildroot}%{_userunitdir}/strata-castd.service
install -Dpm644 packaging/casting/strata-waycast-networkd.service %{buildroot}%{_unitdir}/strata-waycast-networkd.service
install -Dpm644 packaging/casting/org.waycast.Network1.service %{buildroot}%{_datadir}/dbus-1/system-services/org.waycast.Network1.service
install -Dpm644 packaging/casting/org.waycast.Network1.conf %{buildroot}%{_datadir}/dbus-1/system.d/org.waycast.Network1.conf
install -Dpm644 packaging/casting/org.waycast.network.policy %{buildroot}%{_datadir}/polkit-1/actions/org.waycast.network.policy
install -Dpm644 packaging/casting/60-waycast-network.rules %{buildroot}%{_datadir}/polkit-1/rules.d/60-waycast-network.rules
install -Dpm644 packaging/casting/strata-wireless.xml %{buildroot}%{_prefix}/lib/firewalld/zones/strata-wireless.xml

%post -n strata-waycast
%systemd_post strata-waycast-networkd.service
%firewalld_reload

%preun -n strata-waycast
%systemd_preun strata-waycast-networkd.service

%postun -n strata-waycast
%systemd_postun_with_restart strata-waycast-networkd.service
%firewalld_reload

%post -n strata-cast
%systemd_user_post strata-castd.service

%preun -n strata-cast
%systemd_user_preun strata-castd.service

%postun -n strata-cast
%systemd_user_postun strata-castd.service

%files
%license defaults/icons/Win11OSX/LICENSE.txt
%license LICENSE third_party/wiggle/LICENSE shell/plugins/services/media/MEDIA-CONTROL-LICENSE shell/plugins/panels/wireless-display/LICENSE shell/plugins/panels/cast/LICENSE
%license shell/plugins/services/keyboard-osd/KEYGLOW-LICENSE shell/plugins/services/keyboard-osd/LOCK-KEYS-LICENSE
%license shell/plugins/services/shortcut-guide/LICENSE
%license shell/plugins/services/shortcut-guide/KEY-PROMOTER-LICENSE
%license shell/plugins/notifications/center/LICENSE shell/plugins/notifications/center/LICENSE-LUCIDE shell/plugins/notifications/center/LICENSE-OMARCHY
%license shell/plugins/theme-picker/LICENSE
%doc docs/strata-config.md
%{_bindir}/strata-*
%exclude %{_bindir}/strata-castd
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

%files -n strata-casting
%license LICENSE

%files -n strata-waycast
%license third_party/waycast/LICENSE
%{_bindir}/waycast
%{_libexecdir}/strata-waycast-networkd
%{_unitdir}/strata-waycast-networkd.service
%{_datadir}/dbus-1/system-services/org.waycast.Network1.service
%{_datadir}/dbus-1/system.d/org.waycast.Network1.conf
%{_datadir}/polkit-1/actions/org.waycast.network.policy
%{_datadir}/polkit-1/rules.d/60-waycast-network.rules
%{_prefix}/lib/firewalld/zones/strata-wireless.xml

%files -n strata-doubletake
%license doubletake-v0.4.0-alchemy.5-linux-amd64/LICENSE doubletake-v0.4.0-alchemy.5-linux-amd64/COPYING.GPL
%{_bindir}/doubletake
%{_bindir}/doubletake-ctl

%files -n strata-cast
%license third_party/strata-cast/LICENSE
%{_bindir}/strata-castd
%{_userunitdir}/strata-castd.service

%changelog
* Mon Oct 19 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1:1.0.0-1
- Release Strata 1.0.0 with the unified Quickshell desktop and greetd integration
