Name:           strata-config
Version:        0.1.47
Release:        1%{?dist}
Summary:        Desktop configuration defaults for Strata

License:        MIT
URL:            https://github.com/name-is-hai/strata
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       hyprland-desktop-core
Requires:       hyprland-desktop-services
Requires:       ghostty
Requires:       nautilus
Requires:       neovim
Requires:       quickshell >= 0.3.1
Requires:       cliphist >= 0.7.0
Requires:       hypridle
Requires:       hyprlock
Requires:       hyprsunset
Requires:       hyprpicker
Requires:       wf-recorder
Requires:       pipewire-utils
Requires:       pam

%description
Versioned Hyprland, Quickshell, UWSM and portal defaults for Strata.
RPM-owned defaults remain under /usr/share while a small set of
Strata-specific user entry files is installed only when explicitly requested.
Personal application configuration belongs in the separate dotfiles repository.

%prep
%autosetup

%build

%install
install -d %{buildroot}%{_datadir}/strata/user-config
cp -a config/hypr config/uwsm config/xdg-desktop-portal \
    %{buildroot}%{_datadir}/strata/user-config/

install -d %{buildroot}%{_datadir}/strata/default
cp -a default/. %{buildroot}%{_datadir}/strata/default/
cp -a runtime-default/. %{buildroot}%{_datadir}/strata/default/

install -d %{buildroot}%{_datadir}/strata/config
cp -a runtime-config/. %{buildroot}%{_datadir}/strata/config/

install -Dpm 0644 systemd/strata-stay-awake.service \
    %{buildroot}%{_userunitdir}/strata-stay-awake.service
install -Dpm 0644 packaging/strata-lock-password \
    %{buildroot}%{_sysconfdir}/pam.d/strata-lock-password

cp -a bin shell themes docs %{buildroot}%{_datadir}/strata/
cp -a runtime-version %{buildroot}%{_datadir}/strata/version

ln -s %{_datadir}/strata/bin/strata-apply-config \
    %{buildroot}%{_bindir}/strata-apply-config

install -d %{buildroot}%{_datadir}/quickshell/strata
cp -al %{buildroot}%{_datadir}/strata/shell/. \
    %{buildroot}%{_datadir}/quickshell/strata/

for script in scripts/strata-*; do
    install -Dpm 0755 "$script" %{buildroot}%{_bindir}/"$(basename "$script")"
done

%files
%license LICENSE
%doc docs/strata-config.md
%{_bindir}/strata-*
%{_userunitdir}/strata-stay-awake.service
%config(noreplace) %{_sysconfdir}/pam.d/strata-lock-password
%{_datadir}/strata/
%{_datadir}/quickshell/strata/

%changelog
* Wed Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.47-1
- Move into the unified Strata repository
- Stop packaging personal dotfiles; package only Strata desktop entry files

* Wed Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.46-1
- Own the Strata lock PAM policy with the rest of the desktop configuration

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.45-1
- Make Stay Awake inhibit the full hypridle and suspend chain
- Bind screen recording to Super+Shift+R instead of Alt+Print

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.44-1
- Require Neovim for the Hyprland configuration menu action

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.43-1
- Keep shell/ as the single Quickshell source tree
- Generate the compatibility install tree with space-efficient hard links

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.42-1
- Remove the screensaver and lock directly after the configured idle timeout
- Simplify idle status, controls, and packaging around lock-only behavior

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.41-1
- Keep all screen-recording menu levels at the larger capture width

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.40-1
- Add working desktop-audio plus microphone recording to the Fedora backend

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.39-1
- Ask whether to record a selected area or the full focused monitor

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.38-1
- Fix the Fedora recorder fallback so it opens the smart capture picker

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.37-1
- Show active desktop recording and PipeWire screen-sharing status in the bar
- Restore the Omarchy-style recording choices and smart monitor/region picker

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.36-1
- Probe both supported screen recorder backends without a shell wrapper

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.35-1
- Avoid polling the recorder process from the panel

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.34-1
- Fix screen-recording and Stay Awake indicator state refreshes
- Use Ghostty directly for Strata terminal helpers

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.33-1
- Run the installed Strata DNS helper during privilege elevation

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.32-1
- Add portable user defaults for Neovim, Zsh, Starship, Git, Fcitx5, Tmux, and Zed

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.31-1
- Remove 208 unreachable inherited commands from the packaged Strata runtime

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.30-1
- Restore display power after the compositor settles on resume

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.29-1
- Restore display power-off and automatic suspend after idle
- Wake DPMS after the resume delay and keep the lock screen visible after wake

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.28-1
- Fade the Strata menu layer in place instead of using a directional transition

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.27-1
- Keep the hidden menu overlay fullscreen to prevent top-left surface growth

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.26-1
- Keep keybinding help quiet when the optional xkbcli resolver is unavailable

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.25-1
- Route desktop bindings and menu actions through canonical Strata commands
- Replace stale Quickshell IPC targets with current plugin IDs
- Add Fedora grim and wf-recorder fallbacks to the canonical capture commands
- Remove superseded prototype session and capture entry points

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.24-1
- Route the Super+slash launcher binding through the supported Strata menu command

* Thu Oct 08 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.23-1
- Bind the launcher to the physical slash key for layout-independent Super+/

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.22-1
- Move the application launcher binding from Alt+Space to Super+slash

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.21-1
- Stop launching MATE Polkit alongside Strata's native Polkit agent

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.20-1
- Require Quickshell 0.3.1 for the network panel API

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.19-1
- Remove unsupported PanelWindow property so the Background plugin loads

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.18-1
- Use the named Quickshell config in Strata launch, restart, and IPC scripts
- Start the shell through strata-launch-shell at Hyprland login

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.17-1
- Collapse Indicators to active slots and expand to all configured slots on hover

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.16-1
- Disable stale QML disk cache for Strata shell launches

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.15-1
- Report each configured indicator's loaded state and measured width

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.14-1
- Render each configured bar indicator once so hover width equals its slot count

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.13-1
- Report Indicators hover, alwaysShow, and effective settings in bar geometry

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.12-1
- Drive each indicators reveal from its exact owning bar-slot hover state
- Report per-slot hover and indicator reveal state in bar geometry diagnostics

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.11-1
- Size each indicators hover target to its configured indicator-slot count

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.10-1
- Replace overlapping indicator hover flags with one per-instance hover handler

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.9-1
- Derive each hidden indicators hover target from its rendered bar thickness

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.8-1
- Give each indicators widget its own hover target and reveal state

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.7-1
- Keep inactive indicator reveal state local to each bar widget instance

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.6-1
- Reveal inactive bar indicators from their configured left, center, or right section

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.5-1
- Rename the desktop, runtime, commands, and Quickshell namespace to Strata
- Add the direct Strata system-menu IPC endpoint used by SUPER+ESCAPE
- Flatten the source tree to bin/, shell/, runtime-config/, runtime-default/,
  themes/, docs/ and runtime-version instead of a runtime/strata wrapper

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.4-1
- Add the minimal Fedora-oriented Quickshell runtime
- Remove bundled AI, updater, Arch-only, and personal-service integrations
- Keep weather, globe, reminders, and Wi-Fi QR as inactive optional payloads

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.3-1
- Add native clipboard history, emoji picker, and notification center panels
- Replace the Mako notification daemon and Fuzzel fallback dependencies
- Start the cliphist Wayland clipboard watcher with the session

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.2-1
- Add native Quickshell panels for audio, Bluetooth, network, display, and power
- Back panel actions with Fedora desktop service command-line interfaces

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.1-1
- Add reusable toggle bindings for panels and persistent desktop features
- Make color picking and screen recording explicit toggle actions

* Wed Oct 07 2026 Vu Dao Ngoc Hai <nameishai@users.noreply.github.com> - 0.1.0-1
- Create initial Hyprland and Ghostty defaults
- Add a non-destructive per-user configuration installer
- Add the first Quickshell bar, launcher, system menu and IPC interface
