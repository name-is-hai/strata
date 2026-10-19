Name:           strata-casting
Version:        4.0.0~alpha
Release:        1%{?dist}
Summary:        Wireless display and media casting backends for Strata
License:        MIT AND LGPL-3.0-only
URL:            https://github.com/name-is-hai/strata
Source0:        %{name}-%{version}.tar.gz
Source1:        https://github.com/alchemy/waycast/releases/download/v0.6.1/waycast-v0.6.1-linux-amd64.tar.gz
Source2:        https://github.com/alchemy/doubletake/releases/download/v0.4.0-alchemy.5/doubletake-v0.4.0-alchemy.5-linux-amd64.tar.gz
ExclusiveArch:  x86_64
BuildRequires:  cargo >= 1.98
BuildRequires:  rust >= 1.98
BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  systemd-rpm-macros
BuildRequires:  firewalld-filesystem
BuildRequires:  dbus-daemon
Requires:       strata-waycast = %{version}-%{release}
Requires:       strata-doubletake = %{version}-%{release}
Requires:       strata-cast = %{version}-%{release}

%description
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
Requires:       strata-waycast = %{version}-%{release}
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
# Cargo.lock files pin all crate versions. Build in the network-enabled Strata
# container; runtime machines require neither a compiler nor a Rust toolchain.
CARGO_TARGET_DIR="${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}" cargo build --release --locked --manifest-path third_party/waycast/Cargo.toml -p waycast-networkd
CARGO_TARGET_DIR="${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}" cargo build --release --locked --manifest-path third_party/strata-cast/Cargo.toml

%check
CARGO_TARGET_DIR="${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}" cargo test --locked --manifest-path third_party/waycast/Cargo.toml -p waycast-networkd --lib
CARGO_TARGET_DIR="${STRATA_CASTING_BUILD_CACHE:-$PWD/casting-target}" cargo test --locked --manifest-path third_party/strata-cast/Cargo.toml

%install
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
