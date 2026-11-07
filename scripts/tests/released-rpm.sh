#!/usr/bin/env bash
# Exercise release imports without network access or real RPM builds.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary"/{packaging/build,fixtures,bin,out}
cp "$root/packaging/build/"{download-rpm.sh,targets.json} "$temporary/packaging/build/"
asset=$(jq -r '.celluloid.release.asset' "$temporary/packaging/build/targets.json")
printf 'released RPM bytes\n' > "$temporary/fixtures/$asset"
(cd "$temporary/fixtures"; sha256sum "$asset" > SHA256SUMS)
cat > "$temporary/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
for ((i=1; i<=$#; i++)); do
  argument=${!i}
  if [[ $argument == https://* ]]; then file=${argument##*/}; fi
  if [[ $argument == --output ]]; then ((i+=1)); destination=${!i}; fi
done
cp "$FIXTURES/$file" "$destination"
MOCK
chmod +x "$temporary/bin/curl"
export PATH="$temporary/bin:$PATH" FIXTURES="$temporary/fixtures"
bash "$temporary/packaging/build/download-rpm.sh" celluloid "$temporary/out"
cmp "$temporary/fixtures/$asset" "$temporary/out/$asset"
printf 'existing RPM\n' > "$temporary/out/$asset"
printf 'tampered RPM\n' > "$temporary/fixtures/$asset"
if bash "$temporary/packaging/build/download-rpm.sh" celluloid "$temporary/out" 2>/dev/null; then
  echo 'FAIL: accepted a checksum mismatch' >&2; exit 1
fi
[[ $(cat "$temporary/out/$asset") == 'existing RPM' ]]
printf 'no matching asset\n' > "$temporary/fixtures/SHA256SUMS"
if bash "$temporary/packaging/build/download-rpm.sh" celluloid "$temporary/out" 2>/dev/null; then
  echo 'FAIL: accepted a missing checksum' >&2; exit 1
fi
rm "$temporary/fixtures/$asset"
if bash "$temporary/packaging/build/download-rpm.sh" celluloid "$temporary/out" 2>/dev/null; then
  echo 'FAIL: accepted a missing asset' >&2; exit 1
fi
echo 'PASS: release RPM import, checksum rejection, missing assets and existing output preservation'
