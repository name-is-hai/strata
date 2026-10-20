Name:           zen-browser
Epoch:          0
Version:        1.23b
Release:        3%{?dist}
Summary:        Zen Browser from the official Linux release
License:        MPL-2.0
URL:            https://zen-browser.app/
Source0:        https://github.com/zen-browser/desktop/releases/download/%{version}/zen.linux-x86_64.tar.xz#/zen-browser-%{version}-linux-x86_64.tar.xz
Source1:        zen-browser
Source2:        zen-browser.desktop
%global debug_package %{nil}
%global _binary_payload w9.xzdio
BuildRequires:  patchelf
Requires:       zen-browser-engine%{?_isa} = 0:%{version}-%{release}
Requires:       alsa-lib
Requires:       gtk3
Requires:       libXtst
Requires:       mesa-libgbm
Requires:       nss

%description
Zen Browser from the official x86_64 Linux release archive, using the host
Fontconfig and GTK environment.

%package engine
Summary:        Zen Browser rendering engine

%description engine
Matching upstream libxul rendering engine, packaged separately to keep each
RPM within the repository file-size limit.

%prep
%setup -q -c -T
tar -xJf %{SOURCE0}

%build
# The upstream application is prebuilt.

%install
# Zen's official Linux release is a prebuilt, self-contained application.
# Keep its internal directory layout intact: the updater and launcher expect
# relative paths beside the main executable.
install -d %{buildroot}/opt
cp -a zen %{buildroot}/opt/zen-browser
# The upstream archive has a literal "$" RUNPATH on this one library. It is
# invalid on Fedora and makes check-rpaths abort the RPM build.
patchelf --remove-rpath %{buildroot}/opt/zen-browser/libonnxruntime.so
install -Dpm0755 %{SOURCE1} %{buildroot}%{_bindir}/zen-browser
install -Dpm0644 %{SOURCE2} %{buildroot}%{_datadir}/applications/zen-browser.desktop
for size in 16 32 48 64 128; do
  install -Dpm0644 zen/browser/chrome/icons/default/default${size}.png \
    %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps/zen-browser.png
done

%check
test -x zen/zen
test -f zen/libxul.so

%files
%{_bindir}/zen-browser
%{_datadir}/applications/zen-browser.desktop
%{_datadir}/icons/hicolor/*/apps/zen-browser.png
/opt/zen-browser
%exclude /opt/zen-browser/libxul.so

%files engine
/opt/zen-browser/libxul.so

%changelog
* Tue Oct 20 2026 Strata Maintainers <maintainers@strata.dev> - 1.23b-3
- Package Zen Browser and its engine independently from the desktop target
