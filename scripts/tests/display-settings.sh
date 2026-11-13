#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export XDG_CONFIG_HOME="$work/config"
mkdir -p "$work/bin"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "$XDG_CONFIG_HOME/sync-calls"\n' > "$work/bin/strata-hyprland-monitor-clamshell"
chmod +x "$work/bin/strata-hyprland-monitor-clamshell"
export PATH="$work/bin:$PATH"
helper="$repo/bin/strata-display-settings"
"$helper" get | jq -e '.disableOnLidClose==true' >/dev/null
test ! -f "$XDG_CONFIG_HOME/strata/display-settings.json"
"$helper" set disableOnLidClose false
"$helper" get | jq -e '.disableOnLidClose==false' >/dev/null
jq '.other="preserved"' "$XDG_CONFIG_HOME/strata/display-settings.json" > "$work/saved"
cp "$work/saved" "$XDG_CONFIG_HOME/strata/display-settings.json"
"$helper" set disableOnLidClose true
"$helper" get | jq -e '.disableOnLidClose and .other=="preserved"' >/dev/null
[[ $(wc -l < "$XDG_CONFIG_HOME/sync-calls") == 2 ]]
[[ $(sort -u "$XDG_CONFIG_HOME/sync-calls") == sync ]]
if "$helper" set disableOnLidClose bad >/dev/null 2>&1; then exit 1; fi
"$helper" get | jq -e '.disableOnLidClose==true' >/dev/null
echo 'PASS: default lid display preference, persistent changes, immediate synchronization and invalid input'
