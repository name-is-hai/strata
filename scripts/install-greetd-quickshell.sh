#!/usr/bin/env bash
set -euo pipefail

# Prepare the new login manager for the next boot. Never stop the active DE.
if (( EUID != 0 )); then
  echo 'Run with pkexec or sudo.' >&2
  exit 77
fi

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v greetd >/dev/null
command -v agreety >/dev/null
command -v Hyprland >/dev/null
command -v qs >/dev/null
command -v uwsm >/dev/null
getent passwd greetd >/dev/null

install -d -o root -g root -m 0755 /usr/share/strata/greeter /etc/strata /etc/greetd
install -o root -g root -m 0644 "$repo_root/default/greeter/shell.qml" /usr/share/strata/greeter/shell.qml
install -D -o root -g root -m 0644 "$repo_root/shell/Commons/Color.qml" /usr/share/strata/shell/Commons/Color.qml
# Quickshell resolves `qs.*` modules relative to the selected config root.
# The greeter has its own config directory, so expose the shared modules there
# instead of relying on generic Qt import-path variables (which do not define
# Quickshell's `qs` namespace).
ln -sfn ../shell/Commons /usr/share/strata/greeter/Commons
ln -sfn ../shell/Ui /usr/share/strata/greeter/Ui
install -o root -g root -m 0644 "$repo_root/default/greeter/hyprland.lua" /usr/share/strata/greeter/hyprland.lua
rm -f -- /usr/share/strata/greeter/hyprland.conf
install -D -o root -g root -m 0644 \
  "$repo_root/default/polkit-1/rules.d/49-strata-greeter.rules" \
  /etc/polkit-1/rules.d/49-strata-greeter.rules
for helper in strata-greetd-ipc strata-greeter-session strata-greeter-quickshell strata-greeter-gpu \
              strata-greeter-monitors-sync strata-greeter-monitors-install \
              strata-monitor-fallback \
              strata-greeter-background-sync strata-greeter-background-install \
              strata-greeter-theme-sync strata-greeter-theme-install \
              strata-place-cursor-on-main \
              strata-main-monitor-install strata-set-primary-monitor \
              strata-theme-set strata-theme-bg-set strata-font-set; do
  install -o root -g root -m 0755 "$repo_root/bin/$helper" "/usr/bin/$helper"
done
install -D -o root -g root -m 0644 "$repo_root/default/hypr/autostart.lua" \
  /usr/share/strata/default/hypr/autostart.lua

if [[ ! -e /usr/share/strata/greeter/background.sha256 ]]; then
  fallback="$repo_root/themes/lawson-night/backgrounds/wallhaven-1k6ljv.jpg"
  temporary=$(mktemp /tmp/strata-greeter-wallpaper.XXXXXX.jpg)
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$fallback" \
    -vf 'gblur=sigma=18' -frames:v 1 -q:v 3 "$temporary"
  install -o root -g root -m 0644 "$temporary" /usr/share/strata/greeter/background.jpg
  rm -f -- "$temporary"
  sha256sum "$fallback" | cut -d' ' -f1 \
    > /usr/share/strata/greeter/background.sha256
  chmod 0644 /usr/share/strata/greeter/background.sha256
fi
if [[ ! -f /usr/share/strata/greeter/theme.conf ]]; then
  install -o root -g root -m 0644 "$repo_root/default/greeter/theme.conf" \
    /usr/share/strata/greeter/theme.conf
fi

login_name=${STRATA_INSTALL_USER:-${SUDO_USER:-}}
if [[ -z $login_name && ${PKEXEC_UID:-} =~ ^[0-9]+$ ]]; then
  login_name=$(getent passwd "$PKEXEC_UID" | cut -d: -f1)
fi
if [[ -n $login_name && $login_name != root ]] && getent passwd "$login_name" >/dev/null; then
  printf '%s\n' "$login_name" > /etc/strata/login-user
  chmod 0644 /etc/strata/login-user
  login_home=$(getent passwd "$login_name" | cut -d: -f6)
  theme_copy=/usr/share/strata/greeter/theme
  install -d -o root -g root -m 0755 "$theme_copy"
  for pair in "colors.toml:$login_home/.local/state/strata/current/theme/colors.toml" \
              "shell.toml:$login_home/.local/state/strata/current/theme/shell.toml" \
              "user-shell.toml:$login_home/.config/strata/shell.toml"; do
    name=${pair%%:*}
    source=${pair#*:}
    temporary=$(mktemp "$theme_copy/.${name}.XXXXXX")
    if [[ -f $source ]]; then
      source_real=$(realpath -e -- "$source")
      [[ $source_real == "$login_home"/* ]] || { echo 'Theme file escaped login home' >&2; exit 77; }
      install -o root -g root -m 0644 "$source_real" "$temporary"
    else
      : > "$temporary"
      chmod 0644 "$temporary"
    fi
    mv -f -- "$temporary" "$theme_copy/$name"
  done
fi

if [[ -f /etc/greetd/config.toml && ! -e /etc/greetd/config.toml.before-strata ]]; then
  cp -a -- /etc/greetd/config.toml /etc/greetd/config.toml.before-strata
fi
install -o root -g root -m 0644 "$repo_root/default/greeter/config.toml" /etc/greetd/config.toml

# A service enable changes only the next boot. The current desktop continues
# running, which avoids losing the active login during installation.
systemctl disable sddm.service 2>/dev/null || true
systemctl enable --force greetd.service
echo 'greetd is selected for the next boot; the current desktop was not restarted.'
