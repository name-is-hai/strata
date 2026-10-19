#!/bin/bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export HOME=$work/home XDG_CACHE_HOME=$work/cache XDG_RUNTIME_DIR=$work/run STRATA_PATH=$work/stock
mkdir -p "$HOME/.config/strata/themes/active/backgrounds" "$HOME/.local/state/strata/current" "$XDG_RUNTIME_DIR" "$STRATA_PATH/themes" "$work/bin"
printf 'background = "#111111"\nforeground = "#eeeeee"\naccent = "#33aaff"\n' > "$HOME/.config/strata/themes/active/colors.toml"
vips black "$HOME/.config/strata/themes/active/backgrounds/own.png" 64 36
vips black "$work/external.png" 600 200
printf active > "$HOME/.local/state/strata/current/theme.name"
ln -s "$work/external.png" "$HOME/.local/state/strata/current/background"
printf '#!/bin/bash\nprintf '\''[{"width":640,"height":360}]\\n'\''\n' > "$work/bin/hyprctl"
chmod +x "$work/bin/hyprctl"
export PATH=$work/bin:$PATH
"$here/index.sh" > "$work/index.json"
jq -e --arg bg "$work/external.png" '.currentTheme=="active" and .currentBackground==$bg and .activeBackground.path==$bg' "$work/index.json" >/dev/null
key=$(jq -r .activeBackground.key "$work/index.json")
"$here/thumbs.sh"
[[ -f $XDG_CACHE_HOME/strata/swatch/thumbs/bg-$key.jpg ]]
jq -e '.width==600 and .height==200' "$XDG_CACHE_HOME/strata/swatch/thumbs/size-$key.json" >/dev/null
[[ $(vipsheader -f width "$XDG_CACHE_HOME/strata/swatch/thumbs/stage-$key-640x360.jpg") == 600 ]]
[[ $(vipsheader -f height "$XDG_CACHE_HOME/strata/swatch/thumbs/stage-$key-640x360.jpg") == 200 ]]
"$here/image-info.sh" "$XDG_CACHE_HOME/strata/swatch/thumbs" "$key" | jq -e '.width==600 and .height==200' >/dev/null
"$here/index.sh" --selection | jq -e --arg bg "$work/external.png" '.currentTheme=="active" and .currentBackground==$bg and .activeBackground.path==$bg' >/dev/null
# A desktop change after indexing must be read fresh, even with a warm cache.
ln -sfn "$HOME/.config/strata/themes/active/backgrounds/own.png" "$HOME/.local/state/strata/current/background"
"$here/index.sh" --selection | jq -e --arg bg "$HOME/.config/strata/themes/active/backgrounds/own.png" '.currentBackground==$bg and .activeBackground.path==$bg' >/dev/null
"$here/index.sh" --cached | jq -e --arg bg "$HOME/.config/strata/themes/active/backgrounds/own.png" '.currentBackground==$bg and .activeBackground.path==$bg' >/dev/null
mkdir -p "$HOME/.local/state/strata/theme-backgrounds"
printf '%s\n' "$work/external.png" > "$HOME/.local/state/strata/theme-backgrounds/active"
"$here/index.sh" | jq -e --arg bg "$work/external.png" '.themes[] | select(.name=="active") | .preferredBackground=="" and (.backgrounds | index($bg) == null)' >/dev/null
printf '%s\n' "$HOME/.config/strata/themes/active/backgrounds/own.png" > "$HOME/.local/state/strata/theme-backgrounds/active"
"$here/index.sh" | jq -e --arg bg "$HOME/.config/strata/themes/active/backgrounds/own.png" '.themes[] | select(.name=="active") | .preferredBackground==$bg and (.backgrounds | length==1)' >/dev/null
echo 'PASS: live theme, own wallpaper memory, foreign wallpaper isolation and warm-cache refresh'
