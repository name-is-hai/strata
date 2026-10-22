#!/usr/bin/env bash
# Exercise fresh config initialization with the actual offline theme renderer.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-default-theme.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" XDG_RUNTIME_DIR="$work/run"
export XDG_STATE_HOME="$work/home/.local/state"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$work/installed/default" "$work/installed/user-config" "$work/installed/shell"
cp -a "$repo/bin" "$repo/themes" "$work/installed/"
cp -a "$repo/defaults/themed" "$repo/defaults/theme.json" "$work/installed/default/"
printf 'example config\n' > "$work/installed/user-config/example"
sed "s|^strata_root=/usr/share/strata$|strata_root=$work/installed|" "$repo/bin/strata-apply-config" > "$work/apply"
# Dry runs show the intended action but create no state or user config.
bash "$work/apply" --dry-run > "$work/dry-run.log"
[[ ! -e $HOME/.local/state/strata/current && ! -e $XDG_CONFIG_HOME/example ]]
# The real renderer stages the palette and application configs without IPC.
bash "$work/apply" > "$work/fresh.log"
current=$HOME/.local/state/strata/current
[[ $(cat "$current/theme.name") == lawson-night ]]
cmp "$repo/themes/lawson-night/colors.toml" "$current/theme/colors.toml"
[[ -s $current/theme/shell.toml && -s $current/theme/hyprland.lua && -s $current/theme/ghostty.conf ]]
[[ $(readlink -f "$current/background") == "$work/installed/themes/lawson-night/backgrounds/wallhaven-1k6ljv.jpg" ]]
! grep -q '{{' "$current/theme/shell.toml"
# Applying config again, even --force, keeps another personal theme/wallpaper.
printf 'personal-theme\n' > "$current/theme.name"
printf 'personal palette\n' > "$current/theme/colors.toml"
printf 'personal wallpaper\n' > "$work/personal.jpg"
ln -nsf "$work/personal.jpg" "$current/background"
bash "$work/apply" --force > "$work/reapply.log"
[[ $(cat "$current/theme.name") == personal-theme ]]
[[ $(cat "$current/theme/colors.toml") == 'personal palette' ]]
[[ $(readlink -f "$current/background") == "$work/personal.jpg" ]]
# An existing background by itself also counts as a personal selection.
export HOME="$work/background-only" XDG_CONFIG_HOME="$work/background-only/.config"
mkdir -p "$HOME/.local/state/strata/current"
ln -s "$work/personal.jpg" "$HOME/.local/state/strata/current/background"
bash "$work/apply" > "$work/background-only.log"
[[ ! -e $HOME/.local/state/strata/current/theme.name ]]
[[ $(readlink -f "$HOME/.local/state/strata/current/background") == "$work/personal.jpg" ]]
printf 'PASS: fresh default theme and wallpaper, rendered configs, dry-run and preserved user choices\n'
