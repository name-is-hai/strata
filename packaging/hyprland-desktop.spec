%bcond_with zen_only

Name:           hyprland-desktop
# Preserve upgrades from the 4.0.0-alpha development packages.
Epoch:          1
Version:        1.0.1
Release:        1%{?dist}
Summary:        Personal Hyprland desktop package set

License:        MIT AND Unicode-DFS-2016
%global uwsm_version 0.27.0
%global ghostty_version 1.3.1
%global zen_version 1.23b
%global zen_release 3
%global strata_ghostty_cache /var/cache/strata/ghostty-%{ghostty_version}
%global debug_package %{nil}
# Keep large browser payloads compact for the static GitHub Pages repository.
%global _binary_payload w9.xzdio

Source0:        hyprland-desktop-LICENSE
%if %{without zen_only}
Source1:        https://github.com/Vladimir-csp/uwsm/archive/refs/tags/v%{uwsm_version}.tar.gz#/uwsm-%{uwsm_version}.tar.gz
Source2:        https://release.files.ghostty.org/%{ghostty_version}/ghostty-%{ghostty_version}.tar.gz
%endif
Source3:        https://github.com/zen-browser/desktop/releases/download/%{zen_version}/zen.linux-x86_64.tar.xz#/zen-browser-%{zen_version}-linux-x86_64.tar.xz
Source4:        zen-browser
Source5:        zen-browser.desktop

BuildRequires:  patchelf
%if %{without zen_only}
BuildRequires:  gettext
BuildRequires:  gtk4-devel
BuildRequires:  gtk4-layer-shell-devel
BuildRequires:  libadwaita-devel
BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  oniguruma-devel
BuildRequires:  pandoc
BuildRequires:  pkgconfig
BuildRequires:  python3-devel
BuildRequires:  python3-pyxdg
BuildRequires:  scdoc
BuildRequires:  systemd-rpm-macros
BuildRequires:  zig = 0.15.2
%endif

Requires:       %{name}-core = 1:%{version}-%{release}
Requires:       %{name}-services = 1:%{version}-%{release}
Requires:       %{name}-apps = 1:%{version}-%{release}
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
%if %{without zen_only}
tar -xzf %{SOURCE1}
tar -xzf %{SOURCE2}
%endif
tar -xJf %{SOURCE3}

%build
%if %{without zen_only}
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

%endif

%install
install -Dpm0644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE

%if %{without zen_only}
pushd uwsm-%{uwsm_version}
%meson_install
popd

pushd ghostty-%{ghostty_version}
export ZIG_GLOBAL_CACHE_DIR=%{strata_ghostty_cache}
DESTDIR=%{buildroot} zig build --prefix %{_prefix} --system "$ZIG_GLOBAL_CACHE_DIR/p" -Doptimize=ReleaseFast -Dcpu=baseline
popd

%endif

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
test -x zen/zen
test -f zen/libxul.so
%if %{without zen_only}
pushd uwsm-%{uwsm_version}
%meson_test
popd

%endif

%files
%license %{_licensedir}/%{name}/LICENSE

%files core
%license LICENSE

%files services
%license LICENSE

%files apps
%license LICENSE

%if %{without zen_only}
%package -n uwsm
Epoch:          0
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
Epoch:          0
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
Epoch:          0
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

%endif

%package -n zen-browser
Epoch:          0
Version:        %{zen_version}
Release:        %{zen_release}%{?dist}
Summary:        Zen Browser from the official Linux release
License:        MPL-2.0
URL:            https://zen-browser.app/
Requires:       zen-browser-engine%{?_isa} = 0:%{zen_version}-%{zen_release}%{?dist}
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
%exclude /opt/zen-browser/libxul.so

%package -n zen-browser-engine
Epoch:          0
Version:        %{zen_version}
Release:        %{zen_release}%{?dist}
Summary:        Zen Browser rendering engine
License:        MPL-2.0

%description -n zen-browser-engine
The matching upstream libxul rendering engine for Zen Browser. Packaged
separately to keep each downloadable RPM within the repository file-size limit.

%files -n zen-browser-engine
/opt/zen-browser/libxul.so

%changelog
* Mon Oct 19 2026 Strata Maintainers <maintainers@strata.dev> - 1:1.0.1-1
- Align desktop dependency packages with Strata 1.0.1
- Build releases with verified reuse of unchanged targets and Node.js 24 actions

* Mon Oct 19 2026 Strata Maintainers <maintainers@strata.dev> - 1:1.0.0-1
- Release the Strata 1.0.0 desktop package set for Fedora 44
- Use greetd, Zen Browser, Chromium web apps and complete font dependencies
- Keep upstream application versions independent of the Strata release
- Stop requiring Playerctl and Pavucontrol; use native media and audio controls
- Remove Buildah and Skopeo from the default application requirements
- Use RPM Epoch 1 for upgrades from development packages and compact browser payloads
- Split Zen rendering engine into a matching companion RPM for the repository file-size limit
