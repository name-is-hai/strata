#!/usr/bin/env bash
# No real desktop connections, package operations, or private configuration writes.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-doctor-test.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/home" "$work/config/strata" "$work/state" "$work/run" "$work/root"
for file in shell/shell.qml shell/plugins/services/privacy/manifest.json \
 shell/plugins/services/system-sounds/manifest.json default/strata/strata-menu.jsonc; do
 mkdir -p "$work/root/$(dirname "$file")"
 touch "$work/root/$file"
done
printf '1.0.0\n' > "$work/root/version"
printf '{"bar":{"layout":{"left":[],"center":[],"right":[]}}}\n' > "$work/config/strata/shell.json"
cat > "$work/bin/mock" <<'MOCK'
#!/bin/bash
name=${0##*/}
printf '%s\n' "$name $*" >> "$DOCTOR_TRACE"
case $name in
 rpm)
  [[ ${*: -1} != "${DOCTOR_FAIL_PACKAGE:-}" ]] || exit 1
  if [[ $* == *'%{VERSION}-%{RELEASE}'* ]]; then printf '1.0.0-1.fc44'; else printf '1.0.0'; fi
  ;;
 hyprctl) printf '[{"name":"HDMI-A-1"}]\n' ;;
 strata-shell) [[ ${DOCTOR_SHELL_DOWN:-0} == 0 ]] || exit 1; echo ok ;;
 pactl) echo output-test ;;
 *) : ;;
esac
MOCK
chmod +x "$work/bin/mock"
for name in rpm hyprctl quickshell socat wl-copy wl-paste cliphist pw-cli pactl \
 git magick strata-shell strata-snip strata-font-ink strata-wiggle-monitor; do
 ln -s mock "$work/bin/$name"
done
export HOME="$work/home" XDG_CONFIG_HOME="$work/config" XDG_STATE_HOME="$work/state" \
 XDG_RUNTIME_DIR="$work/run" STRATA_PATH="$work/root" WAYLAND_DISPLAY= HYPRLAND_INSTANCE_SIGNATURE= \
 DOCTOR_TRACE="$work/trace" PATH="$work/bin:$PATH"
run() {
 local expected=$1 result=0
 "$repo/bin/strata-doctor" > "$work/output" || result=$?
 [[ $result == "$expected" ]] || { cat "$work/output"; exit 1; }
}
run 0
rg -q '0 failed' "$work/output"
rg -q '\[SKIP\] Live desktop IPC' "$work/output"
export DOCTOR_FAIL_PACKAGE=strata-cast
run 1
rg -q '\[FAIL\] Package strata-cast:' "$work/output"
unset DOCTOR_FAIL_PACKAGE
printf '{invalid\n' > "$work/config/strata/shell.json"
run 1
rg -q '\[FAIL\] Personal shell configuration' "$work/output"
printf '{"bar":{"layout":{}}}\n' > "$work/config/strata/shell.json"
export WAYLAND_DISPLAY=wayland-test
run 0
rg -q '\[OK\] Active displays: HDMI-A-1' "$work/output"
rg -q '\[OK\] Quickshell IPC' "$work/output"
rg -q '\[OK\] Default audio output' "$work/output"
export DOCTOR_SHELL_DOWN=1
run 1
rg -q '\[FAIL\] Quickshell IPC' "$work/output"
unset DOCTOR_SHELL_DOWN
if rg -q '(restart|upgrade|install|set-default|mute|volume)' "$work/trace"; then
 echo 'Doctor attempted a state-changing operation' >&2; exit 1
fi
# CLI dispatch and help must work without executing diagnostics.
"$repo/bin/strata" doctor --help > "$work/help"
rg -q 'strata doctor' "$work/help"
echo 'PASS: doctor checks offline/install and desktop state, rejects broken packages/config/IPC, and performs no state-changing operations'
