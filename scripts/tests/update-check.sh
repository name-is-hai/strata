#!/usr/bin/env bash
# No network, real notifications, privilege escalation, or package changes.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-update-test.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"
printf '%s' '4.0.0~alpha-2.fc44' > "$work/installed"
: > "$work/updates"
cat > "$work/bin/fake" <<'FAKE'
#!/bin/bash
set -euo pipefail
name=${0##*/}
printf '%s\n' "$name $*" >> "$STRATA_TEST_DATA/calls"
case "$name" in
  rpm)
    if [[ $1 == -qa ]]; then cat "$STRATA_TEST_DATA/installed-packages"
    else cat "$STRATA_TEST_DATA/installed"; fi
    ;;
  dnf)
    if [[ -f $STRATA_TEST_DATA/fail ]]; then echo 'Repository unavailable' >&2; exit 1; fi
    cat "$STRATA_TEST_DATA/updates"
    ;;
esac
FAKE
chmod +x "$work/bin/fake"
for name in rpm dnf strata-notification-send sudo strata-shell strata-restart-shell; do ln -s fake "$work/bin/$name"; done
export PATH="$work/bin:$repo/bin:$PATH" STRATA_TEST_DATA="$work" XDG_CACHE_HOME="$work/cache"
count() { awk -v name="$1" '$1==name {n++} END {print n+0}' "$work/calls"; }
check() {
  local expected=$1 code=0
  shift
  status=$(strata-update-check "$@") || code=$?
  [[ $code == "$expected" ]] || { echo "Unexpected checker exit: $code" >&2; exit 1; }
  jq -e . >/dev/null <<<"$status"
}
check 0
jq -e '.available==false' >/dev/null <<<"$status"
check 0
[[ $(count dnf) == 1 ]]
printf 'strata-config\t1:1.0.0-1.fc44\tx86_64\nstrata-lock-auth\t1.1-1.fc44\tx86_64\n' > "$work/updates"
printf 'strata-config\t1:4.0.0~alpha-2.fc44\tx86_64\nstrata-lock-auth\t0:1.0-1.fc44\tx86_64\nstrata-lock-auth\t0:0.9-1.fc44\ti686\n' > "$work/installed-packages"
check 0 --refresh --notify
jq -e '.available and (.updates|length==2) and .updates[0].version=="1:1.0.0-1.fc44"' >/dev/null <<<"$status"
jq -e '.updates[0].installedVersion=="1:4.0.0~alpha-2.fc44" and .updates[1].installedVersion=="1.0-1.fc44"' >/dev/null <<<"$status"
[[ $(count strata-notification-send) == 1 ]]
dnf_before=$(count dnf)
check 0
[[ $(count dnf) == "$dnf_before" ]]
jq -e '.updates[1].installedVersion=="1.0-1.fc44"' >/dev/null <<<"$status"
check 0 --refresh --notify
[[ $(count strata-notification-send) == 1 ]]
touch "$work/fail"
check 1 --refresh
jq -e '.available and (.error|length>0) and (.updates|length==2)' >/dev/null <<<"$status"
rm "$work/fail"
printf 'malformed metadata\n' > "$work/updates"
check 1 --refresh
jq -e '.error|length>0' >/dev/null <<<"$status"
: > "$work/updates"
check 0 --refresh
jq -e '.available==false' >/dev/null <<<"$status"
printf 'strata-config\t4.0.0~alpha-4.fc44\tx86_64\n' > "$work/updates"
check 0 --refresh --notify
[[ $(count strata-notification-send) == 2 ]]
strata-update --check > "$work/check-output"
[[ $(count sudo) == 0 ]]
rg -q '4.0.0~alpha-4.fc44' "$work/check-output"
rg -q '1:4.0.0~alpha-2.fc44 → 4.0.0~alpha-4.fc44' "$work/check-output"
strata-update > "$work/update-output"
[[ $(count sudo) == 1 ]]
[[ $(count strata-restart-shell) == 1 ]]
rg -q '^sudo dnf upgrade --refresh strata-config$' "$work/calls"
if rg -q -- '--assumeyes' "$work/calls"; then echo 'Update skipped confirmation' >&2; exit 1; fi
echo 'PASS: Bash checker/updater, cache, version notifications, offline/malformed metadata, clearing, and explicit transaction'
