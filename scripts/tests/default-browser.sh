#!/usr/bin/env bash
# Verify system default changes and browser-independent desktop entry launching.
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
printf 'Unexpected installation terminal\n' > "$FIXTURE/installed"
exit 1
MOCK
for cmd in chromium firefox flatpak strata-notification-send; do
  printf '#!/bin/sh\nexit 0\n' > "$work/bin/$cmd"
done
chmod +x "$work/bin/"*
export PATH="$work/bin:$repo/bin:$PATH"
printf '[Desktop Entry]\nExec=firefox %%U\n' > "$work/data/applications/firefox.desktop"
printf '[Desktop Entry]\nExec=chromium %%U\n' > "$work/data/applications/chromium.desktop"
printf '[Desktop Entry]\nExec=flatpak run --branch=stable org.example.Browser %%U\n' > "$work/data/applications/org.example.Browser.desktop"
# A change made by the browser itself is reflected on the very next launch.
printf 'firefox.desktop\n' > "$work/default"
strata-launch-browser --private 'https://example.invalid/--private?q=with space'
printf 'firefox\n--private-window\nhttps://example.invalid/--private?q=with space\n' > "$work/expected"
cmp "$work/expected" "$work/launched"
printf 'chromium.desktop\n' > "$work/default"
strata-launch-browser 'https://example.invalid/'
printf 'gio\nlaunch\n%s\nhttps://example.invalid/\n' "$XDG_DATA_HOME/applications/chromium.desktop" > "$work/expected"
cmp "$work/expected" "$work/launched"
# Arbitrary installed browsers, including Flatpaks, keep their full desktop Exec.
strata-default-browser org.example.Browser.desktop
[[ $(<"$work/default") == org.example.Browser.desktop ]]
strata-launch-browser 'https://example.invalid/path with spaces'
printf 'gio\nlaunch\n%s\nhttps://example.invalid/path with spaces\n' "$XDG_DATA_HOME/applications/org.example.Browser.desktop" > "$work/expected"
cmp "$work/expected" "$work/launched"
strata-launch-browser
printf 'gio\nlaunch\n%s\n' "$XDG_DATA_HOME/applications/org.example.Browser.desktop" > "$work/expected"
cmp "$work/expected" "$work/launched"
if strata-default-browser missing.desktop > "$work/missing.log" 2>&1; then
  echo 'Accepted missing desktop entry' >&2; exit 1
fi
[[ $(<"$work/default") == org.example.Browser.desktop ]]
[[ ! -f $work/installed ]]
# A browser's own MIME registration takes precedence over fallback discovery.
printf '[Default Applications]\nx-scheme-handler/http=firefox.desktop;\n' > "$XDG_CONFIG_HOME/mimeapps.list"
[[ $(strata-cmd-default-browser) == firefox.desktop ]]
strata-launch-browser 'https://example.invalid/'
printf 'gio\nlaunch\n%s\nhttps://example.invalid/\n' "$XDG_DATA_HOME/applications/firefox.desktop" > "$work/expected"
cmp "$work/expected" "$work/launched"
strata-default-browser firefox
[[ $(<"$work/default") == firefox.desktop ]]
rm "$work/data/applications/firefox.desktop"
if strata-default-browser firefox > "$work/missing-browser.log" 2>&1; then
  echo 'Accepted missing named browser' >&2; exit 1
fi
grep -q 'Install it first' "$work/missing-browser.log"
[[ $(<"$work/default") == firefox.desktop ]]
if strata-default-browser --install firefox > "$work/obsolete-option.log" 2>&1; then
  echo 'Accepted removed installation option' >&2; exit 1
fi
[[ ! -f $work/installed ]]
printf 'PASS: external default changes, arbitrary desktop IDs, Flatpak launch entries, private native launch and no browser installation\n'
