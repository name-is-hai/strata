Name:           ghostty
Epoch:          0
Version:        1.3.1
Release:        1%{?dist}
Summary:        Fast, feature-rich terminal emulator
License:        MIT
URL:            https://ghostty.org/
Source0:        https://release.files.ghostty.org/%{version}/ghostty-%{version}.tar.gz
%global debug_package %{nil}
%global strata_ghostty_cache /var/cache/strata/ghostty-%{version}

BuildRequires:  gettext
BuildRequires:  gtk4-devel
BuildRequires:  gtk4-layer-shell-devel
BuildRequires:  libadwaita-devel
BuildRequires:  oniguruma-devel
BuildRequires:  pandoc
BuildRequires:  pkgconfig
BuildRequires:  systemd-rpm-macros
BuildRequires:  zig = 0.15.2

%description
Ghostty is a fast, feature-rich terminal emulator built from its official
release source using Zig inside Strata's build container.

%prep
%autosetup

%build
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


%install
export ZIG_GLOBAL_CACHE_DIR=%{strata_ghostty_cache}
DESTDIR=%{buildroot} zig build --prefix %{_prefix} --system "$ZIG_GLOBAL_CACHE_DIR/p" -Doptimize=ReleaseFast -Dcpu=baseline
# Omit the unused SDK while retaining the versioned runtime library.
rm -rf %{buildroot}%{_includedir}/ghostty
rm -f %{buildroot}/usr/lib/libghostty-vt.so %{buildroot}%{_datadir}/pkgconfig/libghostty-vt.pc

%files
%license LICENSE
%doc README.md
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

%changelog
* Tue Oct 20 2026 Strata Maintainers <maintainers@strata.dev> - 1.3.1-1
- Build Ghostty independently and omit unused SDK files
