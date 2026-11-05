#!/usr/bin/env bash
# Real status helper, fixture daemon responses: no PAM or reader access.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-fingerprint-status.XXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir "$work/tools"
cat > "$work/tools/fprintd-list" <<'MOCK'
#!/bin/sh
printf '%s\n' "$*" > "$TEST_USER_LOG"
printf '%s\n' "$TEST_RESPONSE"
exit "${TEST_EXIT:-0}"
MOCK
chmod +x "$work/tools/fprintd-list"
export PATH="$work/tools:$PATH" TEST_USER_LOG="$work/user"
probe() {
  actual=$(TEST_RESPONSE="$1" TEST_EXIT="${3:-0}" "$repo/bin/strata-fingerprint-status" other-user)
  [[ $actual == "$2" ]] || { echo "Expected $2, got $actual" >&2; exit 1; }
  [[ $(cat "$work/user") == other-user ]]
}
probe 'No devices available' no 1
probe 'User other-user has no fingers enrolled for Goodix.' no
probe 'No fingerprints enrolled.' no 1
probe $'Found 1 devices\nUser other-user has fingers enrolled:\n - #0: right-index-finger' yes
probe 'Failed to connect to fprintd: connection timed out' unknown 1
probe 'ListEnrolledFingers failed: PermissionDenied' unknown 1
probe '' unknown 124
echo 'PASS: enrolled user, missing reader, empty enrollment and distinct daemon/permission failures'
