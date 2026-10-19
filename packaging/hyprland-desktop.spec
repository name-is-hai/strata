Name:           hyprland-desktop
Version:        4.0.0~alpha
Release:        1%{?dist}
Summary:        Personal Hyprland desktop package set

License:        MIT AND Unicode-DFS-2016
%global uwsm_version 0.27.0
%global ghostty_version 1.3.1
%global zen_version 1.23b
%global strata_ghostty_cache /var/cache/strata/ghostty-%{ghostty_version}
%global debug_package %{nil}

Source0:        hyprland-desktop-LICENSE
Source1:        https://github.com/Vladimir-csp/uwsm/archive/refs/tags/v%{uwsm_version}.tar.gz#/uwsm-%{uwsm_version}.tar.gz
Source2:        https://release.files.ghostty.org/%{ghostty_version}/ghostty-%{ghostty_version}.tar.gz
Source3:        https://github.com/zen-browser/desktop/releases/download/%{zen_version}/zen.linux-x86_64.tar.xz#/zen-browser-%{zen_version}-linux-x86_64.tar.xz
Source4:        zen-browser
Source5:        zen-browser.desktop

BuildRequires:  gettext
BuildRequires:  gtk4-devel
BuildRequires:  gtk4-layer-shell-devel
BuildRequires:  libadwaita-devel
BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  oniguruma-devel
BuildRequires:  pandoc
BuildRequires:  patchelf
BuildRequires:  pkgconfig
BuildRequires:  python3-devel
BuildRequires:  python3-pyxdg
BuildRequires:  scdoc
BuildRequires:  systemd-rpm-macros
BuildRequires:  zig = 0.15.2

Requires:       %{name}-core = %{version}-%{release}
Requires:       %{name}-services = %{version}-%{release}
Requires:       %{name}-apps = %{version}-%{release}
Requires:       zen-browser >= %{zen_version}

%description
The recommended package set for this personal Fedora Hyprland desktop. The
dependencies are split into independently testable core, desktop-services,
and application layers. They are subpackages of one source RPM so the full
desktop is versioned and built together, while retaining optional install
layers for DNF users.

%package core
Summary:        Core Hyprland session
Requires:       hyprland = 0.56.2-2.fc44
Requires:       hyprland-guiutils = 0.56.2-2.fc44
Requires:       uwsm >= 0.27.0
Requires:       ghostty >= 1.3.1
Requires:       jetbrains-mono-nerd-fonts >= 3.5.1
Requires:       google-noto-sans-cjk-fonts
Requires:       google-noto-emoji-color-fonts
Requires:       greetd
Requires:       greetd-selinux
Requires:       quickshell >= 0.3.1
Requires:       xdg-utils
# A usable Strata login and the small base tools used by its scripts.
Requires:       zsh
Requires:       rsync
Requires:       tar
Requires:       unzip
Requires:       usbutils

%description core
The compositor, session manager, display manager, terminal, shell framework,
and primary font for the desktop.

%package services
Summary:        Fedora services and hardware integration for the Strata desktop

# Network connectivity and local service discovery.
Requires:       NetworkManager
Requires:       NetworkManager-wifi
Requires:       avahi
Requires:       nss-mdns
Requires:       wireless-regdb

# PipeWire audio session and user controls.
Requires:       pipewire
Requires:       pipewire-pulseaudio
Requires:       wireplumber
Requires:       alsa-utils
Requires:       playerctl
Requires:       pavucontrol

# Bluetooth, power, displays, and external hardware.
Requires:       bluez
Requires:       blueman
Requires:       brightnessctl
Requires:       power-profiles-daemon
Requires:       upower
Requires:       ddcutil
Requires:       bolt

# Portals and core Wayland desktop integration.
Requires:       xdg-desktop-portal
Requires:       xdg-desktop-portal-hyprland-upstream >= 1.4.1
Requires:       xdg-desktop-portal-gtk
Requires:       wl-clipboard
Requires:       grim
Requires:       slurp
Requires:       wtype
Requires:       libnotify
Requires:       socat
Requires:       jq
Requires:       inotify-tools

# Secret storage. Strata's Quickshell process supplies the Polkit agent.
Requires:       gnome-keyring
Requires:       gnome-keyring-pam
Requires:       libsecret

# Removable media, network shares, and per-user directories.
Requires:       gvfs
Requires:       gvfs-mtp
Requires:       gvfs-smb
Requires:       gvfs-nfs
Requires:       udisks2
Requires:       udiskie
Requires:       xdg-user-dirs

%description services
Fedora-native networking, audio, Bluetooth, power, portal, authorization,
secret-storage, removable-media, clipboard, and capture integration used by
the Strata Hyprland session.

%package apps
Summary:        Fedora applications for the Strata desktop

# Standalone web apps; Zen remains the default browser.
Requires:       chromium

# File management, archives, previews, and storage administration.
Requires:       nautilus
Requires:       file-roller
Requires:       gnome-disk-utility
Requires:       sushi

# Fedora-native rootless containers and development environments.
Requires:       podman
Requires:       podman-compose
Requires:       buildah
Requires:       skopeo
Requires:       toolbox

# Desktop application and system utilities.
Requires:       flatpak
Requires:       fastfetch
Requires:       btop
Requires:       rsync

%description apps
The primary file-management, archive, preview, storage, rootless-container,
Flatpak, and system utility applications for the Strata desktop.

%prep
cp -p %{SOURCE0} LICENSE
tar -xzf %{SOURCE1}
tar -xzf %{SOURCE2}
tar -xJf %{SOURCE3}

%build
pushd uwsm-%{uwsm_version}
%meson -Duuctl=enabled -Dfumon=enabled -Duwsm-app=enabled -Dttyautolock=enabled
%meson_build
popd

pushd ghostty-%{ghostty_version}
export ZIG_GLOBAL_CACHE_DIR=%{strata_ghostty_cache}
for attempt in 1 2 3 4; do
  if ./nix/build-support/fetch-zig-cache.sh; then
    break
  fi
  if [ "$attempt" -eq 4 ]; then
    exit 1
  fi
  echo "Ghostty dependency fetch failed; retrying in 10 seconds (attempt $attempt/4)" >&2
  sleep 10
done
popd

%install
install -Dpm0644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE

pushd uwsm-%{uwsm_version}
%meson_install
popd

pushd ghostty-%{ghostty_version}
export ZIG_GLOBAL_CACHE_DIR=%{strata_ghostty_cache}
DESTDIR=%{buildroot} zig build --prefix %{_prefix} --system "$ZIG_GLOBAL_CACHE_DIR/p" -Doptimize=ReleaseFast -Dcpu=baseline
popd

# Zen's official Linux release is a prebuilt, self-contained application.
# Keep its internal directory layout intact: the updater and launcher expect
# relative paths beside the main executable.
install -d %{buildroot}/opt
cp -a zen %{buildroot}/opt/zen-browser
# The upstream archive has a literal "$" RUNPATH on this one library. It is
# invalid on Fedora and makes check-rpaths abort the RPM build.
patchelf --remove-rpath %{buildroot}/opt/zen-browser/libonnxruntime.so
install -Dpm0755 %{SOURCE4} %{buildroot}%{_bindir}/zen-browser
install -Dpm0644 %{SOURCE5} %{buildroot}%{_datadir}/applications/zen-browser.desktop
for size in 16 32 48 64 128; do
  install -Dpm0644 zen/browser/chrome/icons/default/default${size}.png \
    %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps/zen-browser.png
done

%check
pushd uwsm-%{uwsm_version}
%meson_test
popd

%files
%license %{_licensedir}/%{name}/LICENSE

%files core
%license LICENSE

%files services
%license LICENSE

%files apps
%license LICENSE

%package -n uwsm
Version:        %{uwsm_version}
Release:        1%{?dist}
Summary:        Universal Wayland Session Manager
Requires:       python3-dbus
Requires:       python3-pyxdg
Requires:       systemd
Requires:       util-linux

%description -n uwsm
UWSM manages standalone Wayland compositor sessions through the systemd user
manager. Strata uses it to launch and shut down Hyprland cleanly.

%files -n uwsm
%license uwsm-%{uwsm_version}/LICENSE
%doc uwsm-%{uwsm_version}/README.md
%{_bindir}/fumon
%{_bindir}/ttyautolock
%{_bindir}/uuctl
%{_bindir}/uwsm
%{_bindir}/uwsm-app
%{_bindir}/uwsm-terminal
%{_bindir}/uwsm-terminal-scope
%{_bindir}/uwsm-terminal-service
%{_datadir}/applications/uuctl.desktop
%{_docdir}/uwsm/example-units
%{_datadir}/uwsm
%{_libexecdir}/uwsm
%{_mandir}/man1/*
%{_mandir}/man3/*
%{_userpresetdir}/*
%{_userunitdir}/*

%package -n ghostty
Version:        %{ghostty_version}
Release:        1%{?dist}
Summary:        Fast, feature-rich terminal emulator

%description -n ghostty
Ghostty is a fast, feature-rich terminal emulator. It is built from the
official release source using Zig only inside Strata's build container.

%files -n ghostty
%license ghostty-%{ghostty_version}/LICENSE
%doc ghostty-%{ghostty_version}/README.md
%{_bindir}/ghostty
%{_datadir}/applications/com.mitchellh.ghostty.desktop
%{_datadir}/bash-completion/completions/ghostty.bash
%{_datadir}/bat/syntaxes/ghostty.sublime-syntax
%{_datadir}/dbus-1/services/com.mitchellh.ghostty.service
%{_datadir}/fish/vendor_completions.d/ghostty.fish
%{_datadir}/ghostty
%{_datadir}/icons/hicolor/*/apps/com.mitchellh.ghostty.*
%{_datadir}/kio/servicemenus/com.mitchellh.ghostty.desktop
%{_datadir}/locale/*/LC_MESSAGES/com.mitchellh.ghostty.mo
%{_datadir}/metainfo/com.mitchellh.ghostty.metainfo.xml
%{_datadir}/nautilus-python/extensions/ghostty.py
%{_datadir}/nvim/site/*/ghostty.vim
%{_datadir}/vim/vimfiles/*/ghostty.vim

%{_datadir}/zsh/site-functions/_ghostty
%{_datadir}/terminfo/*/*
/usr/lib/libghostty-vt.so.0*
%{_mandir}/man1/ghostty.1*
%{_mandir}/man5/ghostty.5*
%{_userunitdir}/app-com.mitchellh.ghostty.service

%package -n ghostty-vt-devel
Version:        %{ghostty_version}
Release:        1%{?dist}
Summary:        Development files for Ghostty's terminal library
Requires:       ghostty%{?_isa} = %{ghostty_version}-1%{?dist}

%description -n ghostty-vt-devel
Headers and pkg-config metadata for applications using libghostty-vt.

%files -n ghostty-vt-devel
%{_includedir}/ghostty
/usr/lib/libghostty-vt.so
%{_datadir}/pkgconfig/libghostty-vt.pc

%package -n zen-browser
Version:        %{zen_version}
Release:        2%{?dist}
Summary:        Zen Browser from the official Linux release
License:        MPL-2.0
URL:            https://zen-browser.app/
Requires:       alsa-lib
Requires:       gtk3
Requires:       libXtst
Requires:       mesa-libgbm
Requires:       nss

%description -n zen-browser
Zen Browser is installed from the official x86_64 Linux release archive. It
uses the host Fontconfig and GTK environment, so fonts installed for the
current Fedora system are available to the browser.

%files -n zen-browser
%{_bindir}/zen-browser
%{_datadir}/applications/zen-browser.desktop
%{_datadir}/icons/hicolor/*/apps/zen-browser.png
/opt/zen-browser

%changelog
* Sat Oct 17 2026 Strata Maintainers <maintainers@strata.dev> - 4.0.0~alpha-1
- Align desktop package versions with the Strata alpha release

* Sun Oct 11 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-22
- Require Noto CJK and color emoji fonts for Unicode fallback in desktop apps
- Keep Zen browser text independent from the desktop text-size setting

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-21
- Package Zen Browser from its official x86_64 Linux release archive

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-20
- Include Zsh and the base archive, sync, and USB utilities in the desktop core

* Sat Oct 10 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-19
- Build Ghostty and UWSM as sibling packages of the desktop source RPM

* Fri Oct 09 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-17
- Accept Fedora 44's supported Ghostty and UWSM versions instead of pinning
  newer minimum versions unavailable from Fedora repositories

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-16
- Consolidate core, services, and application meta-packages into one spec
- Move the Strata lock PAM policy into the configuration package

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-15
- Require the services layer that uses Strata's native Polkit agent

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-14
- Require the tested Fedora PAM service for the Strata lock screen

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-13
- Require tagged Quickshell 0.3.1 or newer for Strata networking APIs

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-12
- Drop the Fuzzel and Mako fallback package after native Quickshell validation

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-11
- Move hyprland-desktop-apps into its own independently built source RPM
- Keep application rebuilds independent from the compositor and service stack

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-10
- Move hyprland-desktop-services into its own independently built source RPM
- Allow the service layer to be rebuilt and tested without rebuilding the
  desktop package collection

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-9
- Split dependencies into core, desktop-services, apps, and optional layers
- Keep Fuzzel and Mako as optional fallbacks while Quickshell UI is developed

* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-8
- Add the Quickshell, launcher, notifications, Flatpak, and desktop utility group

* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-7
- Add Wi-Fi, Bluetooth, audio tools, power management, and device discovery

* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-6
- Add the Podman container toolchain and Toolbox

* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-5
- Add Nautilus and removable-drive, network-share, archive, and preview support

* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-4
- Require the packaged JetBrains Mono Nerd Font family

* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-3
- Require the Hyprland portal backend built by the combined Hyprland spec

* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-2
- Add the core networking, audio, portal, authentication, and utility packages

* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 1.0-1
- Create the personal Hyprland desktop dependency package
