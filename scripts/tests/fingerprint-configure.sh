#!/usr/bin/env bash
# Exercise hardware gating and Fedora authselect operations without touching PAM.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-fingerprint-test.XXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir "$work/tools"
export PATH="$work/tools:$PATH" FINGERPRINT_TEST_LOG="$work/calls"
# All privileged commands are fixtures; allow this isolated copy to run unprivileged.
sed '/^(( EUID == 0 ))/d' "$repo/bin/strata-fingerprint-configure" > "$work/configure"
cat > "$work/tools/authselect" <<'MOCK'
#!/usr/bin/env bash
printf 'authselect %s\n' "$*" >> "$FINGERPRINT_TEST_LOG"
case $1 in
  check) exit "${TEST_INVALID:-0}" ;;
  current) echo "${TEST_SELECTION:-local with-mdns4 with-silent-lastlog}" ;;
  list-features) [[ ${TEST_UNSUPPORTED:-0} == 1 ]] || echo with-fingerprint ;;
  enable-feature) exit "${TEST_ENABLE_ERROR:-0}" ;;
  *) exit 99 ;;
esac
MOCK
cat > "$work/tools/busctl" <<'MOCK'
#!/usr/bin/env bash
printf 'busctl %s\n' "$*" >> "$FINGERPRINT_TEST_LOG"
[[ ${TEST_BUS_ERROR:-0} == 0 ]] || exit 1
echo "${TEST_DEVICES:-ao 1 \"/net/reactivated/Fprint/Device/0\"}"
MOCK
chmod +x "$work/tools/"*
run() { : > "$work/calls"; bash "$work/configure" > "$work/output" 2>&1; }
run
grep -qx 'authselect enable-feature with-fingerprint -b' "$work/calls"
grep -qx 'authselect list-features local' "$work/calls"
grep -q 'busctl --system --timeout=10s call' "$work/calls"
! grep -Eq 'authselect (select|apply-changes)' "$work/calls"
TEST_DEVICES='ao 0' run
! grep -q enable-feature "$work/calls"
TEST_BUS_ERROR=1 run
! grep -q enable-feature "$work/calls"
TEST_UNSUPPORTED=1 run
! grep -Eq 'busctl|enable-feature' "$work/calls"
TEST_SELECTION='custom/company with-mdns4' run
grep -qx 'authselect list-features custom/company' "$work/calls"
TEST_SELECTION='local with-fingerprint with-mdns4' run
! grep -Eq 'busctl|enable-feature' "$work/calls"
if TEST_INVALID=1 run; then echo 'Accepted modified PAM configuration' >&2; exit 1; fi
! grep -Eq 'busctl|enable-feature' "$work/calls"
if TEST_ENABLE_ERROR=1 run; then echo 'Ignored failed authselect update' >&2; exit 1; fi
printf 'PASS: fingerprint reader gating, existing profiles/features, backup, idempotence and PAM modification refusal\n'
