#!/usr/bin/env bash
# Fake extraction runtime, real installer/launchers/desktop validation, isolated HOME.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-appimage-test.XXXXXX)
trap 'rm -rf "$work"' EXIT
export HOME="$work/home with spaces" XDG_DATA_HOME="$work/data with spaces"
export PATH="$work/tools:$repo/bin:$PATH" TEST_APPIMAGE_WORK="$work"
mkdir -p "$HOME" "$work/tools" "$work/downloads"
# Only the marker reader is mocked: the fixture is a shell extraction runtime,
# not an ELF AppImage. All path/metadata/icon/font/launch logic runs unchanged.
cat > "$work/tools/od" <<'MOCK'
#!/usr/bin/env bash
if grep -q '^# FAKE_APPIMAGE_TEST$' "${@: -1}"; then echo '41 49 02'; else echo '00 00 00'; fi
MOCK
for command in update-desktop-database gtk-update-icon-cache; do
  printf '#!/bin/sh\nexit 0\n' > "$work/tools/$command"
done
chmod +x "$work/tools/"*
printf '#!/bin/sh\nprintf "\047Desktop UI 11\047\\n"\n' > "$work/tools/gsettings"
printf '#!/bin/sh\nprintf "%%s\\n" "${TEST_UI_FONT:-Desktop UI}"\n' > "$work/tools/fc-match"
chmod +x "$work/tools/gsettings" "$work/tools/fc-match"
cat > "$work/downloads/Sample App.AppImage" <<'APP'
#!/usr/bin/env bash
# FAKE_APPIMAGE_TEST
set -euo pipefail
if [[ ${1:-} == --appimage-extract ]]; then
  mkdir -p AppDir
  cat > AppDir/sample.desktop <<'DESKTOP'
[Desktop Entry]
Name=Sample App
Type=Application
Exec=AppRun
Icon=sample
DESKTOP
  printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aIdkAAAAASUVORK5CYII=' | base64 -d > AppDir/sample.png
  ln -s sample.png AppDir/.DirIcon
  printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "$TEST_APPIMAGE_WORK/launched"\n' > AppDir/AppRun
  chmod +x AppDir/AppRun
  if [[ ${TEST_ZADARK:-} == 1 ]]; then
    mkdir -p AppDir/app/pc-dist/zadark/js AppDir/app/pc-dist/zadark/css
    printf '.icon{font-family:icons}.ztext-font{font-family:SegoeuiPcText}\n' > AppDir/app/pc-dist/zadark/css/zadark.min.css
    cat > AppDir/app/pc-dist/zadark/js/zadark.min.js <<'JS'
const settings={getFontFamily:()=>{const t=localStorage.getItem("@ZaDark:FONT_FAMILY");return null===t?"Open Sans":t},initFontFamily:async function(){const t=this.getFontFamily();await this.installFontFamily([t]);this.setFontFamilyAttr(t)},initPageSettings:function(){}};
JS
  fi
else
  printf '%s\n' "${FONTCONFIG_FILE:-system}" "$@" > "$TEST_APPIMAGE_WORK/launched"
fi
APP
strata-appimage install "$work/downloads/Sample App.AppImage" > "$work/install.log"
[[ -x $HOME/.local/bin/sample && -x $HOME/.local/bin/sample.AppImage ]]
[[ -f $XDG_DATA_HOME/applications/strata-appimage-sample.desktop ]]
[[ -f $XDG_DATA_HOME/icons/hicolor/512x512/apps/strata-appimage-sample.png ]]
[[ $(jq -r .adapter "$XDG_DATA_HOME/strata/appimages/sample/metadata.json") == native ]]
[[ -f $work/downloads/'Sample App.AppImage' ]]
FONTCONFIG_FILE=/custom/system/fonts.conf "$HOME/.local/bin/sample" 'a file with spaces' 'literal $(no-command)'
printf '/custom/system/fonts.conf\na file with spaces\nliteral $(no-command)\n' > "$work/expected"
cmp "$work/expected" "$work/launched"
if strata-appimage install "$work/downloads/Sample App.AppImage" > /dev/null 2>&1; then echo 'Accepted a conflicting installation' >&2; exit 1; fi
mkdir -p "$HOME/.config/SampleApp"
echo profile > "$HOME/.config/SampleApp/data"
strata-appimage remove sample > /dev/null
[[ ! -e $HOME/.local/bin/sample && ! -e $HOME/.local/bin/sample.AppImage ]]
[[ ! -e $XDG_DATA_HOME/applications/strata-appimage-sample.desktop ]]
[[ ! -e $XDG_DATA_HOME/icons/hicolor/512x512/apps/strata-appimage-sample.png ]]
[[ -f $HOME/.config/SampleApp/data ]]
if strata-appimage remove sample > /dev/null 2>&1; then echo 'Removed an unknown application' >&2; exit 1; fi
if strata-appimage install "$work/downloads/Sample App.AppImage" --id '../escape' > /dev/null 2>&1; then echo 'Accepted path traversal ID' >&2; exit 1; fi
TEST_ZADARK=1 strata-appimage install "$work/downloads/Sample App.AppImage" --id font-test > /dev/null
adapter="$XDG_DATA_HOME/strata/appimages/font-test/AppDir/app/pc-dist/zadark/js/zadark.min.js"
grep -q 'getFontFamily:()=>"system-ui"' "$adapter"
grep -q 'initFontFamily:function(){this.setFontFamilyAttr("system-ui")}' "$adapter"
style=${adapter%/js/zadark.min.js}/css/zadark.min.css
grep -q -- '--strata-system-font:"Desktop UI"' "$style"
grep -q 'body,body.zadark,.ztext-font,.message-view' "$style"
grep -q '.icon{font-family:icons}' "$style"
strata-appimage launch font-test 'test argument'
printf 'test argument\n' > "$work/expected"
cmp "$work/expected" "$work/launched"
TEST_UI_FONT='Changed Desktop Font' strata-appimage launch font-test
grep -q -- '--strata-system-font:"Changed Desktop Font"' "$style"
[[ $(grep -c 'strata-system-font:start' "$style") == 1 ]]
TEST_ZADARK=1 strata-appimage install "$work/downloads/Sample App.AppImage" --id app-font --font app > /dev/null
[[ $(jq -r .adapter "$XDG_DATA_HOME/strata/appimages/app-font/metadata.json") == native ]]
printf 'Not an AppImage' > "$work/downloads/not-appimage"
if strata-appimage install "$work/downloads/not-appimage" > /dev/null 2>&1; then echo 'Accepted a non-AppImage' >&2; exit 1; fi
printf 'PASS: AppImage install, bundled icon, menu entry, safe arguments, paths with spaces, font adapters, collisions, removal and preserved profiles\n'
