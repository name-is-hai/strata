Name:           hyprland-desktop
# Preserve upgrades from the 4.0.0-alpha development packages.
Epoch:          1
Version:        1.1.1
Release:        1%{?dist}
Summary:        Personal Hyprland desktop package set

License:        MIT AND Unicode-DFS-2016
%global debug_package %{nil}

Source0:        hyprland-desktop-LICENSE

Requires:       %{name}-core = 1:%{version}-%{release}
Requires:       %{name}-services = 1:%{version}-%{release}
Requires:       %{name}-apps = 1:%{version}-%{release}
Requires:       zen-browser >= 1.23b

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
%setup -q -c -T
cp -p %{SOURCE0} LICENSE

%build
# Dependency-only packages.

%install
install -Dpm0644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE

%files
%license %{_licensedir}/%{name}/LICENSE

%files core
%license LICENSE

%files services
%license LICENSE

%files apps
%license LICENSE

%changelog
* Tue Oct 20 2026 Strata Maintainers <maintainers@strata.dev> - 1:1.1.1-1
- Build desktop dependency packages separately from Ghostty, Zen and UWSM
- Align the Strata package version with release 1.1.1

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
