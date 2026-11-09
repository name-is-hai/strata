#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
flags=(-std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror)
gcc "${flags[@]}" -fPIC -shared "$repo/packaging/pam_strata_polkit.c" -lpam -pthread -o "$work/pam_strata_polkit.so"
gcc "${flags[@]}" -fPIC -shared -DTEST_PAM_MODULE "$repo/packaging/polkit-password-switch-test.c" -lpam -o "$work/test-pam.so"
gcc "${flags[@]}" "$repo/packaging/polkit-password-switch-test.c" -lpam -o "$work/polkit-agent-helper-1"
gcc "${flags[@]}" -DSTRATA_POLKIT_HELPER="\"$work/polkit-agent-helper-1\"" "$repo/packaging/strata-polkit-use-password.c" -o "$work/switch"
cat > "$work/polkit-1" <<EOF
auth optional $work/pam_strata_polkit.so
auth sufficient $work/test-pam.so fingerprint
auth required $work/test-pam.so password
EOF
"$work/polkit-agent-helper-1" "$work/polkit-agent-helper-1" "$work" "$work/switch"
