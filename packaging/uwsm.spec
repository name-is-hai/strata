Name:           uwsm
Epoch:          0
Version:        0.27.0
Release:        1%{?dist}
Summary:        Universal Wayland Session Manager
License:        MIT
URL:            https://github.com/Vladimir-csp/uwsm
Source0:        https://github.com/Vladimir-csp/uwsm/archive/refs/tags/v%{version}.tar.gz#/uwsm-%{version}.tar.gz
BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  python3-devel
BuildRequires:  python3-pyxdg
BuildRequires:  scdoc
BuildRequires:  systemd-rpm-macros
Requires:       python3-dbus
Requires:       python3-pyxdg
Requires:       systemd
Requires:       util-linux

%description
UWSM manages standalone Wayland compositor sessions through the systemd user
manager. Strata uses it to launch and shut down Hyprland cleanly.

%prep
%autosetup

%build
%meson -Duuctl=enabled -Dfumon=enabled -Duwsm-app=enabled -Dttyautolock=enabled
%meson_build

%install
%meson_install

%check
%meson_test

%files
%license LICENSE
%doc README.md
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

%changelog
* Tue Oct 20 2026 Strata Maintainers <maintainers@strata.dev> - 0.27.0-1
- Build UWSM independently from the desktop dependency packages
