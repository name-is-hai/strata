#!/usr/bin/env bash
# Run the actual wake rule generator without touching the compositor.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir "$fixture/bin"
printf '#!/bin/sh\necho eDP-1\n' > "$fixture/bin/strata-hyprland-monitor-laptop"
chmod +x "$fixture/bin/strata-hyprland-monitor-laptop"
export PATH="$fixture/bin:$PATH"
sed '/^strata-hyprland-monitor-internal recover/,$d' "$repo/bin/strata-hyprland-monitor-clamshell" > "$fixture/functions.sh"
source "$fixture/functions.sh"
MONITOR_LUA="$fixture/monitors.lua"
cat > "$MONITOR_LUA" <<'LUA'
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "-864x120", scale = 1.25, transform = 3 })
LUA
hyprctl() {
  if [[ $1 == monitors ]]; then cat "$fixture/live.json"
  elif [[ $1 == eval ]]; then printf '%s\n' "$2" > "$fixture/applied.lua"
  else return 1; fi
}
cat > "$fixture/live.json" <<'JSON'
[{"name":"eDP-1","width":1920,"height":1080,"refreshRate":120,"x":-720,"y":80,"scale":1.5,"transform":1,"mirrorOf":"none"}]
JSON
enable_internal_output 1.25
grep -Fq 'transform = 1' "$fixture/applied.lua"
grep -Fq 'position = "-720x80"' "$fixture/applied.lua"
grep -Fq 'mode = "1920x1080@120"' "$fixture/applied.lua"
grep -Fq 'scale = 1.25' "$fixture/applied.lua"
printf '[{"name":"eDP-1","disabled":true,"width":0,"height":0,"transform":0}]\n' > "$fixture/live.json"
enable_internal_output 1.25
grep -Fq 'transform = 3' "$fixture/applied.lua"
grep -Fq 'position = "-864x120"' "$fixture/applied.lua"
grep -Fq 'mode = "1920x1080@60"' "$fixture/applied.lua"
echo 'PASS: wake scale correction retains active rotation/placement/mode; disabled output restores saved geometry'
