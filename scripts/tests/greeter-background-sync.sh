#!/usr/bin/env bash
# Verify cache invalidation with isolated files and a fake privileged installer.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-greeter-sync-test.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/greeter"
sed "s|/usr/share/strata/greeter/|$work/greeter/|g" \
  "$repo/bin/strata-greeter-background-sync" > "$work/sync"
cat > "$work/bin/pkexec" <<'MOCK'
#!/bin/bash
printf 'install\n' >> "$TEST_CALLS"
MOCK
chmod +x "$work/bin/pkexec"
export PATH="$work/bin:$PATH" TEST_CALLS="$work/calls"
printf 'current desktop wallpaper' > "$work/source.jpg"
printf 'blurred greeter snapshot' > "$work/greeter/background.jpg"
sha256sum "$work/source.jpg" | cut -d' ' -f1 > "$work/greeter/background.sha256"
run() { bash "$work/sync" "$work/source.jpg"; }
# Old one-hash state must be migrated even when its source hash matches.
run
test $(wc -l < "$work/calls") == 1
sha256sum "$work/greeter/background.jpg" | cut -d' ' -f1 > "$work/greeter/background-output.sha256"
run
test $(wc -l < "$work/calls") == 1
# This reproduces an RPM replacing the JPEG but retaining the old source hash.
printf 'package default wallpaper' > "$work/greeter/background.jpg"
run
test $(wc -l < "$work/calls") == 2
sha256sum "$work/greeter/background.jpg" | cut -d' ' -f1 > "$work/greeter/background-output.sha256"
printf 'another selected wallpaper' > "$work/source.jpg"
run
test $(wc -l < "$work/calls") == 3
rm "$work/greeter/background.jpg"
run
test $(wc -l < "$work/calls") == 4
echo 'PASS: greeter cache migration, valid cache, replaced JPEG, changed source and missing snapshot'
