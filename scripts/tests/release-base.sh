#!/usr/bin/env bash
# Exercise optional baseline downloads locally; never contact GitHub.
set -euo pipefail
script=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.github/scripts/download-release-base.sh
work=$(mktemp -d /tmp/strata-release-base-test.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/assets" "$work/site/packages" "$work/checkout"
printf 'rpm fixture' > "$work/site/packages/example.rpm"
printf '{"schema":1}\n' > "$work/assets/release-manifest.json"
tar -C "$work/site" -czf "$work/assets/strata-repository-f44-x86_64.tar.gz" ./packages
(cd "$work/assets"; sha256sum *.json *.tar.gz > SHA256SUMS)
cat > "$work/bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'called\n' >> "$FIXTURE/calls"
if [[ $2 == list ]]; then
  if [[ $MODE == unavailable ]]; then exit 1; fi
  printf '[{"tagName":"v1.0.0","publishedAt":"2026-10-19T00:00:00Z"}]\n'
else
  while [[ $1 != --dir ]]; do shift; done
  destination=$2
  if [[ $MODE == missing ]]; then exit 1; fi
  cp "$FIXTURE"/assets/* "$destination/"
  if [[ $MODE == corrupt ]]; then printf 'broken' >> "$destination/release-manifest.json"; fi
fi
MOCK
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" FIXTURE="$work" TAG=v1.0.1 FORCE_FULL=false
cd "$work/checkout"
MODE=valid bash "$script" > "$work/result" 2>&1
test -f build-output/reuse-base/packages/example.rpm
for mode in unavailable missing corrupt; do
  rm -rf build-output
  MODE=$mode bash "$script" > "$work/result" 2>&1
  test ! -f build-output/reuse-base/release-manifest.json
  test ! -d build-output/reuse-base/packages
  grep -Fq 'all targets will be built' "$work/result"
done
rm "$work/calls"
FORCE_FULL=true MODE=unavailable bash "$script"
test ! -f "$work/calls"
echo 'PASS: release baseline download, missing assets, checksum rejection, network fallback and forced build'
