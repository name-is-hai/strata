Name:           hyprland-desktop
Version:        1.0
Release:        17%{?dist}
Summary:        Personal Hyprland desktop package set

License:        MIT
Source0:        hyprland-desktop-LICENSE

BuildArch:      noarch
Requires:       %{name}-core = %{version}-%{release}
Requires:       %{name}-services = %{version}-%{release}
Requires:       %{name}-apps = %{version}-%{release}

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
Requires:       uwsm
Requires:       ghostty
Requires:       jetbrains-mono-nerd-fonts >= 3.5.1
Requires:       sddm
Requires:       quickshell >= 0.3.1
Requires:       xdg-utils

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

%build

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
