#!/usr/bin/env bash
# Exercise the real commands in a disposable checkout; never mutate the source.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/strata-release-version.XXXXXXXX)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/packaging"
cp "$repo"/bin/{strata,strata-cmd-repo-root,strata-release-version,strata-package-version} "$fixture/bin/"
cp "$repo"/packaging/*.spec "$fixture/packaging/"
cp "$repo"/{VERSION,runtime-version} "$fixture/"
export STRATA_REPO_DIR=$fixture
cd "$fixture"
release=bin/strata-release-version
package=bin/strata-package-version
before=$(sha256sum packaging/*.spec runtime-version)
message='Keep literal \n and 100% text'
"$release" 9.0.0 -m 'Update Ghostty' -m "$message"
[[ $before == "$(sha256sum packaging/*.spec runtime-version)" ]]
[[ $(<VERSION) == 9.0.0 ]]
grep -Fxq -- "- $message" .github/release-notes.md
"$release" --check
printf '9.0.3\n' > VERSION
if "$release" --check >/dev/null 2>&1; then echo 'Stale release notes accepted' >&2; exit 1; fi
"$release"
grep -Fxq '# Strata 9.0.3' .github/release-notes.md
"$release" --check
"$release" 9.0.0 -m 'Restore release fixture'
notes=$(sha256sum .github/release-notes.md)
"$release"
[[ $notes == "$(sha256sum .github/release-notes.md)" ]]
for option in missing empty check; do
  case "$option" in missing) set -- -m;; empty) set -- -m '';; check) set -- --check -m 'Invalid';; esac
  if "$release" "$@" >/dev/null 2>&1; then echo 'Invalid arguments accepted' >&2; exit 1; fi
done
other=$(sha256sum VERSION runtime-version packaging/{strata-config,hyprland-desktop,hyprland-utilities,zen-browser,uwsm}.spec)
"$package" ghostty 9.0.1 -m 'Update only Ghostty' -m "$message"
[[ $other == "$(sha256sum VERSION runtime-version packaging/{strata-config,hyprland-desktop,hyprland-utilities,zen-browser,uwsm}.spec)" ]]
grep -Fxq -- "- $message" packaging/ghostty.spec
[[ $(awk '/^Version:/ {print $2; exit}' packaging/ghostty.spec) == 9.0.1 ]]
"$package" ghostty 9.0.1 -m 'Fix packaging without an upstream version change'
[[ $(awk '/^Release:/ {print $2; exit}' packaging/ghostty.spec) == '2%{?dist}' ]]
"$package" config 9.0.2 -m 'Update the shell'
[[ $(<runtime-version) == 9.0.2 && $(<VERSION) == 9.0.0 ]]
"$release" --check
printf 'broken\n' > runtime-version
if "$release" --check >/dev/null 2>&1; then echo 'Runtime/spec mismatch accepted' >&2; exit 1; fi
before=$(sha256sum VERSION packaging/*.spec)
if "$package" ghostty 'bad/version' >/dev/null 2>&1; then exit 1; fi
if "$package" ghostty 1.0 --release 0 >/dev/null 2>&1; then exit 1; fi
[[ $before == "$(sha256sum VERSION packaging/*.spec)" ]]
printf 'PASS: release-only versions, literal notes, independent RPM bumps, packaging releases and config runtime validation\n'
