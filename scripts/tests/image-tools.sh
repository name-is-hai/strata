#!/usr/bin/env bash
# Exercise real ImageMagick operations with temporary files and no desktop UI.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-image-tools.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
export HOME=$work/home XDG_CACHE_HOME=$work/cache XDG_RUNTIME_DIR=$work/run
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$work/bin" "$work/images" "$XDG_CACHE_HOME/strata/swatch"
magick -size 1200x600 gradient:red-blue "$work/images/one.jpg"
magick -size 240x160 xc:none -fill red -draw 'rectangle 20,20 100,100' "$work/images/two.png"
magick -size 640x320 xc:red -delay 10 -size 640x320 xc:blue -loop 0 "$work/images/three.gif"
magick -size 160x80 xc:green "$work/images/four.webp"
jq -n --arg dir "$work/images" '{version:2,partial:false,stageW:320,stageH:200,currentTheme:"test",themes:[{name:"test",backgrounds:[$dir+"/one.jpg",$dir+"/two.png",$dir+"/three.gif",$dir+"/four.webp"],bgKeys:["0000000000000001","0000000000000002","0000000000000003","0000000000000004"]}]}' > "$XDG_CACHE_HOME/strata/swatch/index.json"
bash "$repo/shell/plugins/theme-picker/thumbs.sh"
thumbs=$XDG_CACHE_HOME/strata/swatch/thumbs
expected=('320x160' '240x160' '320x160' '160x80')
for n in 1 2 3 4; do
 key=$(printf '%016d' "$n")
 [[ $(magick identify -ping -format '%wx%h %m' "$thumbs/stage-$key-320x200.jpg") == "${expected[n-1]} JPEG" ]]
 [[ $(magick identify -ping -format '%n' "$thumbs/bg-$key.jpg") == 1 ]]
 jq -e '.width>0 and .height>0' "$thumbs/size-$key.json" >/dev/null
done
# Menu thumbnails remain centered and cropped to the fixed 16:9 canvas.
rows=$(bash "$repo/bin/strata-menu-images" --print-rows "$work/images")
[[ $(printf '%s\n' "$rows" | wc -l) == 4 ]]
while IFS=$'\t' read -r original preview; do
 [[ -f $original && $(magick identify -ping -format '%wx%h %m' "$preview") == '1536x864 JPEG' ]]
done <<<"$rows"
# Run the actual screenshot fallback using a synthetic frozen frame.
magick -size 100x60 xc:red -fill blue -draw 'rectangle 50,0 99,59' "$work/frame.png"
export TEST_FRAME=$work/frame.png TEST_CAPTURE=$work/capture.png
cat > "$work/bin/grim" <<'MOCK'
#!/bin/bash
cp "$TEST_FRAME" "$1"
MOCK
cat > "$work/bin/slurp" <<'MOCK'
#!/bin/bash
echo '60,10 30x20'
MOCK
cat > "$work/bin/wl-copy" <<'MOCK'
#!/bin/bash
cat > "$TEST_CAPTURE"
MOCK
for cmd in strata-shell strata-notification-send; do
 printf '#!/bin/bash\nexit 0\n' > "$work/bin/$cmd"
done
chmod +x "$work/bin/"*
env PATH="$work/bin:$PATH" STRATA_SNIP_BIN="$work/no-native-selector" bash "$repo/bin/strata-capture-screenshot" region copy
[[ $(magick identify -ping -format '%wx%h %X %Y' "$TEST_CAPTURE") == '30x20 +0 +0' ]]
[[ $(magick "$TEST_CAPTURE" -format '%[pixel:p{0,0}]' info:) == *'0,0,255'* ]]
echo 'PASS: JPEG/PNG/GIF/WebP previews, no stage upscaling, single-frame thumbnails, menu center crops and screenshot fallback pixels'
