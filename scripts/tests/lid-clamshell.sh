#!/usr/bin/env bash
# Real clamshell/sync scripts against a simulated compositor; no host changes.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/"{bin,runtime,config/hypr,toggles}
export STRATA_LID_FIXTURE="$work" XDG_RUNTIME_DIR="$work/runtime" XDG_CONFIG_HOME="$work/config"
export PATH="$work/bin:$PATH"
sed 's#^TOGGLES_DIR=.*#TOGGLES_DIR="$STRATA_LID_FIXTURE/toggles"#' "$repo/bin/strata-hyprland-monitor-clamshell" > "$work/clamshell"
for command in strata-hyprland-monitor-internal strata-hyprland-monitor-internal-mirror strata-monitor-fallback; do
  printf '#!/bin/sh\nexit 0\n' > "$work/bin/$command"; chmod +x "$work/bin/$command"
done
cat > "$work/bin/strata-hyprland-monitor-laptop" <<'MOCK'
#!/bin/bash
jq -r '.[] | select(.name|test("^(eDP|LVDS|DSI)-")) | .name' "$STRATA_LID_FIXTURE/live.json"
MOCK
cat > "$work/bin/hyprctl" <<'MOCK'
#!/bin/bash
set -euo pipefail
work=$STRATA_LID_FIXTURE
case $1 in
  monitors) cat "$work/live.json" ;;
  configerrors) ;;
  eval)
    printf '%s\n' "$2" >> "$work/applied"
    [[ $2 == 'hl.monitor({ output = "eDP-1", disabled = true })' ]]
    jq 'map(if .name=="eDP-1" then .disabled=true else . end)' "$work/live.json" > "$work/next.json"
    mv "$work/next.json" "$work/live.json" ;;
  reload)
    [[ ! -f $work/reload-fails ]] || exit 1
    echo reload >> "$work/applied"
    jq --slurpfile saved "$work/saved.json" 'map(if .name=="eDP-1" then $saved[0] else . end)' "$work/live.json" > "$work/next.json"
    mv "$work/next.json" "$work/live.json" ;;
  dispatch) echo "$2" >> "$work/applied" ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$work/bin/hyprctl" "$work/bin/strata-hyprland-monitor-laptop"
ln -s "$repo/bin/strata-hyprland-monitor-external-active" "$work/bin/strata-hyprland-monitor-external-active"
cat > "$work/config/hypr/monitors.lua" <<'LUA'
hl.monitor({ output = "eDP-1", mode = "1920x1080@120", position = "-864x120", scale = 1.25, transform = 1 })
LUA
cp "$work/config/hypr/monitors.lua" "$work/original.lua"
cat > "$work/live.json" <<'JSON'
[{"name":"eDP-1","disabled":false,"width":1920,"height":1080,"refreshRate":120,"x":-864,"y":120,"scale":1.25,"transform":1},{"name":"HDMI-A-1","disabled":false,"width":2560,"height":1440,"scale":1}]
JSON
jq '.[0]' "$work/live.json" > "$work/saved.json"
bash "$work/clamshell" closed
jq -e '.[0].disabled and (.[1].disabled|not)' "$work/live.json" >/dev/null
jq -e '.name=="eDP-1" and .disabled==false and .scale==1.25' "$work/runtime/strata-monitor-clamshell.json" >/dev/null
bash "$repo/bin/strata-greeter-monitors-sync" --print > "$work/greeter.json"
jq -e '.[0].disabled==false and .[0].scale==1.25' "$work/greeter.json" >/dev/null
bash "$work/clamshell" closed
[[ $(grep -c '^hl.monitor' "$work/applied") == 1 ]]
touch "$work/reload-fails"
if bash "$work/clamshell" open; then echo 'FAIL: failed restore reported success'; exit 1; fi
test -f "$work/runtime/strata-monitor-clamshell.json"
rm "$work/reload-fails"
bash "$work/clamshell" open
test ! -f "$work/runtime/strata-monitor-clamshell.json"
diff <(jq '.[0]' "$work/live.json") "$work/saved.json"
cmp "$work/original.lua" "$work/config/hypr/monitors.lua"
# Disabling the preference while closed restores the temporary override and
# prevents later close events from deactivating the saved laptop layout.
bash "$work/clamshell" closed
mkdir -p "$work/config/strata"
echo '{"disableOnLidClose":false}' > "$work/config/strata/display-settings.json"
bash "$work/clamshell" closed
jq -e '.[0].disabled==false' "$work/live.json" >/dev/null
test ! -f "$work/runtime/strata-monitor-clamshell.json"
bash "$work/clamshell" closed
jq -e '.[0].disabled==false' "$work/live.json" >/dev/null
echo '{"disableOnLidClose":true}' > "$work/config/strata/display-settings.json"
# Close again, then unplug the external display while closed: keep a usable
# laptop panel rather than disabling the last physical output.
bash "$work/clamshell" closed
jq 'map(select(.name=="eDP-1"))' "$work/live.json" > "$work/next.json"
mv "$work/next.json" "$work/live.json"
bash "$work/clamshell" closed
jq -e '.[0].disabled==false' "$work/live.json" >/dev/null
test ! -f "$work/runtime/strata-monitor-clamshell.json"
# A virtual FALLBACK output is not a usable external monitor.
jq '. + [{name:"FALLBACK",disabled:false,width:1920,height:1080}]' "$work/live.json" > "$work/next.json"
mv "$work/next.json" "$work/live.json"
if strata-hyprland-monitor-external-active; then echo 'FAIL: FALLBACK counted as external'; exit 1; fi
# A capture output is not a physical external display: closing the laptop lid
# during RDP must not remove the only physical destination for disconnect.
jq '. + [{name:"hypr-rdp-strata",disabled:false,width:1920,height:1080},{name:"HEADLESS-2",disabled:false,width:1920,height:1080}]' "$work/live.json" > "$work/next.json"
mv "$work/next.json" "$work/live.json"
if strata-hyprland-monitor-external-active; then echo 'FAIL: RDP capture counted as a physical external display'; exit 1; fi
jq 'map(select(.name!="hypr-rdp-strata" and .name!="HEADLESS-2"))' "$work/live.json" > "$work/next.json"
mv "$work/next.json" "$work/live.json"
# An explicitly disabled saved panel must stay disabled when the lid opens.
jq '.disabled=true' "$work/saved.json" > "$work/next.json"; mv "$work/next.json" "$work/saved.json"
jq '.[0].disabled=true | . + [{name:"HDMI-A-1",disabled:false,width:2560,height:1440}]' "$work/live.json" > "$work/next.json"
mv "$work/next.json" "$work/live.json"
bash "$work/clamshell" closed
test ! -f "$work/runtime/strata-monitor-clamshell.json"
bash "$work/clamshell" open
jq -e '.[0].disabled==true' "$work/live.json" >/dev/null
# Lid detection works on fresh machines without legacy ACPI proc files.
source=$(cat "$repo/bin/strata-hw-laptop-closed")
source=${source//\/proc\/acpi\/button\/lid/$work/lid}
printf '%s\n' "$source" > "$work/laptop-closed"
cat > "$work/bin/busctl" <<'MOCK'
#!/bin/bash
case $STRATA_TEST_LID in true|false) echo "b $STRATA_TEST_LID";; *) exit 1;; esac
MOCK
chmod +x "$work/bin/busctl"
STRATA_TEST_LID=true bash "$work/laptop-closed"
mkdir -p "$work/lid/LID"
echo 'state: closed' > "$work/lid/LID/state"
if STRATA_TEST_LID=false bash "$work/laptop-closed"; then echo 'FAIL: stale proc state overrode logind'; exit 1; fi
STRATA_TEST_LID=unavailable bash "$work/laptop-closed"
echo 'PASS: temporary lid deactivation, unchanged saved layout/greeter policy, restore geometry, repeated events, failed reload and last-display safety'
