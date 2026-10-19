#!/bin/bash
# Real selection handshake and application dispatch, with no desktop changes.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
repo=$(cd "$here/../../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/shell/plugins"
ln -s "$here" "$work/shell/plugins/theme-picker"
export STRATA_PATH=$work PATH=$work/bin:$PATH
export TEST_APPLY=$here/apply.sh TEST_TRACE=$work/trace TEST_WALLPAPER=$work/'wall paper.jpg'
export HOME=$work/home XDG_STATE_HOME=$work/state
touch "$TEST_WALLPAPER"
mkdir -p "$XDG_STATE_HOME/strata/current"
ln -s "$TEST_WALLPAPER" "$XDG_STATE_HOME/strata/current/background"
cat > "$work/bin/strata-shell" <<'STUB'
#!/bin/bash
if [[ $1 == shell && $2 == summon ]]; then
 [[ $3 == strata.theme-picker ]] || exit 1
 mode=$(jq -r .mode <<< "$4")
 dir=$(jq -r .dir <<< "$4")
 [[ $mode == backgrounds ]] || exit 1
 if [[ ${TEST_CANCEL:-0} == 1 ]]; then
  "$TEST_APPLY" --pick-background "$dir" ''
 else
  "$TEST_APPLY" --pick-background "$dir" "$TEST_WALLPAPER"
 fi
 echo ok
elif [[ $1 == background && $2 == ready ]]; then
 echo "${TEST_READY:-ready}"
else
 printf 'instant\n' >> "$TEST_TRACE"
fi
STUB
cat > "$work/bin/strata-theme-bg-set" <<'STUB'
#!/bin/bash
[[ $# == 1 && $1 == "$TEST_WALLPAPER" ]] || exit 1
printf 'background\n' >> "$TEST_TRACE"
STUB
cat > "$work/bin/strata-theme-set" <<'STUB'
#!/bin/bash
echo 'Unexpected theme application' >&2
exit 99
STUB
chmod +x "$work/bin/"*
selected=$(bash "$repo/bin/strata-theme-bg-switcher")
[[ $selected == "$TEST_WALLPAPER" && ! -e $TEST_TRACE ]]
if TEST_CANCEL=1 bash "$repo/bin/strata-theme-bg-switcher" > "$work/cancel"; then
 echo 'Cancel unexpectedly succeeded' >&2; exit 1
fi
[[ ! -s $work/cancel && ! -e $TEST_TRACE ]]
"$here/apply.sh" --background "$TEST_WALLPAPER"
[[ $(cat "$TEST_TRACE") == $'instant\nbackground' ]]
if "$here/apply.sh" --background relative.jpg; then exit 1; fi
mkdir "$work/invalid"
"$here/apply.sh" --pick-background "$work/invalid" relative.jpg
[[ -e $work/invalid/done && ! -e $work/invalid/selection ]]
[[ $(TEST_READY=ready "$here/land.sh" "$TEST_WALLPAPER" | tail -n1) == ready ]]
[[ $(TEST_READY=waiting "$here/land.sh" "$TEST_WALLPAPER" | tail -n1) == waiting ]]
echo 'PASS: background selection, cancel, spaced paths and wallpaper-only application'
# A wallpaper-only choice belongs to its collection, not the active theme.
mkdir -p "$STRATA_PATH/themes/selected/backgrounds" "$HOME/.local/state/strata/current" "$HOME/.local/state/strata/theme-backgrounds"
export TEST_WALLPAPER=$STRATA_PATH/themes/selected/backgrounds/choice.jpg
touch "$TEST_WALLPAPER"
printf active > "$HOME/.local/state/strata/current/theme.name"
printf '/keep/active.jpg\n' > "$HOME/.local/state/strata/theme-backgrounds/active"
"$here/apply.sh" --background "$TEST_WALLPAPER" selected
[[ $(cat "$HOME/.local/state/strata/theme-backgrounds/selected") == "$TEST_WALLPAPER" ]]
[[ $(cat "$HOME/.local/state/strata/theme-backgrounds/active") == /keep/active.jpg ]]
# Switching themes while a foreign image is on the desktop preserves the
# outgoing theme's last own selection, despite the stock command's state write.
mkdir -p "$STRATA_PATH/themes/active/backgrounds"
touch "$STRATA_PATH/themes/active/backgrounds/own.jpg"
printf '%s\n' "$STRATA_PATH/themes/active/backgrounds/own.jpg" > "$HOME/.local/state/strata/theme-backgrounds/active"
ln -s "$TEST_WALLPAPER" "$HOME/.local/state/strata/current/background"
cat > "$work/bin/strata-theme-set" <<'STUB'
#!/bin/bash
printf '%s\n' "$TEST_WALLPAPER" > "$HOME/.local/state/strata/theme-backgrounds/active"
STUB
"$here/apply.sh" selected "$TEST_WALLPAPER"
[[ $(cat "$HOME/.local/state/strata/theme-backgrounds/active") == "$STRATA_PATH/themes/active/backgrounds/own.jpg" ]]
echo 'PASS: wallpaper-only choice remembers its owner; switching preserves outgoing own choice'
