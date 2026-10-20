#!/usr/bin/env bash
# Simulate external XDG changes and verify the real browser selection/launcher.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-default-browser.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/home/.config" "$work/data/applications"
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" XDG_CONFIG_DIRS="$work/empty"
export XDG_DATA_HOME="$work/data" XDG_DATA_DIRS="$work/empty" FIXTURE="$work"
unset HYPRLAND_INSTANCE_SIGNATURE
cat > "$work/bin/xdg-settings" <<'MOCK'
#!/usr/bin/env bash
if [[ $1 == get ]]; then cat "$FIXTURE/default"; else printf '%s\n' "$3" > "$FIXTURE/default"; fi
MOCK
cat > "$work/bin/systemd-run" <<'MOCK'
#!/usr/bin/env bash
while (( $# )); do
  if [[ $1 == uwsm-app ]]; then shift 2; printf '%s\n' "$@" > "$FIXTURE/launched"; exit 0; fi
  shift
done
exit 1
MOCK
cat > "$work/bin/strata-cmd-browser-handoff" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
cat > "$work/bin/strata-launch-floating-terminal-with-presentation" <<'MOCK'
#!/usr/bin/env bash
printf 'terminal\n' > "$FIXTURE/terminal"
exec bash -c "$1"
MOCK
cat > "$work/bin/strata-install-browser" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == zen ]] || exit 1
printf 'installed\n' > "$FIXTURE/installed"
mkdir -p "$HOME/.tarball-installations/zen" "$HOME/.local/bin"
printf '#!/bin/sh\nexit 0\n' > "$HOME/.tarball-installations/zen/zen"
printf '#!/bin/sh\nexit 0\n' > "$HOME/.local/bin/zen-browser"
chmod +x "$HOME/.tarball-installations/zen/zen" "$HOME/.local/bin/zen-browser"
printf '[Desktop Entry]\nExec=zen-browser %%U\n' > "$XDG_DATA_HOME/applications/zen.desktop"
MOCK
for cmd in chromium firefox strata-notification-send; do
  printf '#!/bin/sh\nexit 0\n' > "$work/bin/$cmd"
done
chmod +x "$work/bin/"*
export PATH="$work/bin:$repo/bin:$PATH"
printf '[Desktop Entry]\nExec=firefox %%U\n' > "$work/data/applications/firefox.desktop"
printf '[Desktop Entry]\nExec=chromium %%U\n' > "$work/data/applications/chromium.desktop"
# A change made by the browser itself is reflected on the very next launch.
printf 'firefox.desktop\n' > "$work/default"
strata-launch-browser --private 'https://example.invalid/--private?q=with space'
printf 'firefox\n--private-window\nhttps://example.invalid/--private?q=with space\n' > "$work/expected"
cmp "$work/expected" "$work/launched"
printf 'chromium.desktop\n' > "$work/default"
strata-launch-browser 'https://example.invalid/'
printf 'chromium\nhttps://example.invalid/\n' > "$work/expected"
cmp "$work/expected" "$work/launched"
[[ ! -f $work/installed ]]
# Selecting Zen checks the actual application, even if an old wrapper exists.
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\nexit 0\n' > "$HOME/.local/bin/zen-browser"
chmod +x "$HOME/.local/bin/zen-browser"
strata-default-browser zen
[[ $(<"$work/default") == zen.desktop ]]
test -f "$work/installed"
test -f "$work/terminal"
strata-launch-browser --private 'https://example.invalid/'
printf '%s\n--private-window\nhttps://example.invalid/\n' "$HOME/.local/bin/zen-browser" > "$work/expected"
cmp "$work/expected" "$work/launched"
printf 'firefox.desktop\n' > "$work/default"
strata-launch-browser 'https://example.invalid/'
printf 'firefox\nhttps://example.invalid/\n' > "$work/expected"
cmp "$work/expected" "$work/launched"
printf 'PASS: external default changes, optional Zen selection, private arguments and user desktop entries\n'
