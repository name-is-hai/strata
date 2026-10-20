#!/usr/bin/env bash
# Test actual installer and launcher with a tiny tarball, without network or GUI.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-zen-install.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/source/zen/browser/chrome/icons/default" "$work/home/.zen/profile"
printf 'existing profile\n' > "$work/home/.zen/profile/prefs.js"
cat > "$work/source/zen/zen" <<'APP'
#!/usr/bin/env bash
printf '%s\n' "$GDK_DPI_SCALE" "$@" > "$FIXTURE/launched"
APP
chmod +x "$work/source/zen/zen"
printf 'engine\n' > "$work/source/zen/libxul.so"
printf 'icon\n' > "$work/source/zen/browser/chrome/icons/default/default128.png"
tar -cJf "$work/zen.tar.xz" -C "$work/source" zen
cat > "$work/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'download\n' >> "$FIXTURE/downloads"
while (( $# )); do
  if [[ $1 == --output ]]; then destination=$2; break; fi
  shift
done
if [[ ${MODE:-} == fail ]]; then printf 'partial' > "$destination"; exit 22; fi
cp "$FIXTURE/zen.tar.xz" "$destination"
MOCK
cat > "$work/bin/uname" <<'MOCK'
#!/usr/bin/env bash
printf 'x86_64\n'
MOCK
cat > "$work/bin/update-desktop-database" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
cat > "$work/bin/rpm" <<'MOCK'
#!/usr/bin/env bash
if [[ ${MODE:-} == missing && ${@: -1} == gtk3 ]]; then exit 1; fi
exit 0
MOCK
cat > "$work/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FIXTURE/dependencies"
MOCK
chmod +x "$work/bin/"*
export HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" FIXTURE="$work"
export XDG_CONFIG_HOME="$work/home/.config"
export PATH="$work/bin:$repo/bin:$PATH"
profile=$(sha256sum "$HOME/.zen/profile/prefs.js")
strata-install-zen
[[ -x $HOME/.tarball-installations/zen/zen ]]
[[ $(stat -c '%u' "$HOME/.tarball-installations/zen/zen") == "$(id -u)" ]]
grep -Fxq 'Exec=zen-browser %U' "$XDG_DATA_HOME/applications/zen.desktop"
grep -Fxq 'NoDisplay=true' "$XDG_DATA_HOME/applications/zen-browser.desktop"
[[ $(wc -l < "$work/downloads") == 1 ]]
[[ ! -e $work/dependencies ]]
MODE=missing strata-install-zen
grep -Fxq gtk3 "$work/dependencies"
if grep -Fxq nss "$work/dependencies"; then echo 'Already installed dependency requested again' >&2; exit 1; fi
# A self-update must survive a later explicit installer run without a download.
printf '# self-updated\n' >> "$HOME/.tarball-installations/zen/zen"
application=$(sha256sum "$HOME/.tarball-installations/zen/zen")
printf 'custom launcher\n' > "$XDG_DATA_HOME/applications/zen.desktop"
printf 'custom command\n' > "$HOME/.local/bin/zen-browser"
strata-install-zen
[[ $application == "$(sha256sum "$HOME/.tarball-installations/zen/zen")" ]]
[[ $(wc -l < "$work/downloads") == 1 ]]
grep -Fxq 'custom launcher' "$XDG_DATA_HOME/applications/zen.desktop"
grep -Fxq 'custom command' "$HOME/.local/bin/zen-browser"
if MODE=fail strata-install-zen --force > "$work/failure.log" 2>&1; then echo 'Failed download accepted' >&2; exit 1; fi
[[ $application == "$(sha256sum "$HOME/.tarball-installations/zen/zen")" ]]
# A valid archive missing its engine must also leave the old application intact.
rm "$work/source/zen/libxul.so"
tar -cJf "$work/zen.tar.xz" -C "$work/source" zen
if strata-install-zen --force > "$work/incomplete.log" 2>&1; then echo 'Incomplete browser accepted' >&2; exit 1; fi
[[ $application == "$(sha256sum "$HOME/.tarball-installations/zen/zen")" ]]
[[ -z $(find "$HOME/.tarball-installations" -maxdepth 1 -name '.zen-install.*' -print -quit) ]]
[[ $profile == "$(sha256sum "$HOME/.zen/profile/prefs.js")" ]]
"$HOME/.local/bin/zen" --private-window 'https://example.invalid/path with spaces'
printf '1\n--private-window\nhttps://example.invalid/path with spaces\n' > "$work/expected"
cmp "$work/expected" "$work/launched"
# The new installation path must still open the former native profile.
cat > "$HOME/.zen/profiles.ini" <<'PROFILE'
[Profile0]
Name=Default User
IsRelative=1
Path=profile
[InstallOLDHASH]
Default=profile
Locked=1
PROFILE
profile_index=$(sha256sum "$HOME/.zen/profiles.ini")
"$HOME/.local/bin/zen" 'https://example.invalid/'
printf '1\n--profile\n%s\nhttps://example.invalid/\n' "$HOME/.zen/profile" > "$work/expected"
cmp "$work/expected" "$work/launched"
[[ $profile_index == "$(sha256sum "$HOME/.zen/profiles.ini")" ]]
mkdir -p "$XDG_CONFIG_HOME/zen"
cp "$HOME/.zen/profiles.ini" "$XDG_CONFIG_HOME/zen/profiles.ini"
mkdir -p "$XDG_CONFIG_HOME/zen/profile"
"$HOME/.local/bin/zen" 'https://example.invalid/'
printf '1\n--profile\n%s\nhttps://example.invalid/\n' "$XDG_CONFIG_HOME/zen/profile" > "$work/expected"
cmp "$work/expected" "$work/launched"
"$HOME/.local/bin/zen" --profile /another/profile
printf '1\n--profile\n/another/profile\n' > "$work/expected"
cmp "$work/expected" "$work/launched"
# Explicit browser installation also works through the shared installer.
printf 'engine\n' > "$work/source/zen/libxul.so"
tar -cJf "$work/zen.tar.xz" -C "$work/source" zen
export HOME="$work/second-home" XDG_DATA_HOME="$work/second-home/.local/share"
export XDG_CONFIG_HOME="$work/second-home/.config"
strata-install-browser zen
"$HOME/.local/bin/zen" 'https://example.invalid/'
[[ -x $HOME/.tarball-installations/zen/zen ]]
printf '1\nhttps://example.invalid/\n' > "$work/expected"
cmp "$work/expected" "$work/launched"
printf 'PASS: user-owned Zen, desktop aliases, existing profiles, custom launchers, self-updates, failure recovery and first launch\n'
