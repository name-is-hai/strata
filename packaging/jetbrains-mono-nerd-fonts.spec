Name:           jetbrains-mono-nerd-fonts
Version:        3.5.1
Release:        1%{?dist}
Summary:        JetBrains Mono patched with Nerd Fonts glyphs

License:        OFL-1.1
URL:            https://www.nerdfonts.com/
Source0:        https://github.com/ryanoasis/nerd-fonts/releases/download/v%{version}/JetBrainsMono.tar.xz

BuildArch:      noarch
BuildRequires:  fontconfig

%description
The monospaced JetBrains Mono family patched with Nerd Fonts icons and
symbols. This package installs the fixed-width Nerd Font Mono variants for
terminals, editors, and desktop shells.

%prep
%autosetup -c

%build

%install
install -dm0755 %{buildroot}%{_datadir}/fonts/jetbrains-mono-nerd
install -pm0644 JetBrainsMonoNerdFontMono-*.ttf \
    %{buildroot}%{_datadir}/fonts/jetbrains-mono-nerd/

%check
test "$(find %{buildroot}%{_datadir}/fonts/jetbrains-mono-nerd \
    -maxdepth 1 -type f -name '*.ttf' | wc -l)" -eq 16
find %{buildroot}%{_datadir}/fonts/jetbrains-mono-nerd \
    -maxdepth 1 -type f -name '*.ttf' -exec fc-scan --format '%%{family}\n' {} \; \
    | grep -F 'JetBrainsMono Nerd Font Mono' >/dev/null

%files
%license OFL.txt
%doc README.md
%dir %{_datadir}/fonts/jetbrains-mono-nerd
%{_datadir}/fonts/jetbrains-mono-nerd/*.ttf

%changelog
* Tue Oct 06 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 3.5.1-1
- Package the tagged JetBrains Mono Nerd Font Mono family
