#!/usr/bin/env bash
# Exercise publication gates with isolated RPM headers and DNF metadata mocks.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-repo-verify-test.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/source/bin" "$work/source/packaging" "$work/source/packages" "$work/source/repodata"
cp "$repo"/packaging/*.spec "$work/source/packaging/"
touch "$work/source/bin/strata" "$work/source/repodata/repomd.xml"
for spec in "$repo"/packaging/*.spec; do
  rpmspec -q --qf $'%{NAME}\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}\n' "$spec"
done > "$work/metadata.good"
while IFS=$'\t' read -r name version; do touch "$work/source/packages/$name.rpm"; done < "$work/metadata.good"
cp "$work/metadata.good" "$work/metadata"
cat > "$work/bin/rpm" <<'MOCK'
#!/bin/bash
name=${@: -1}
name=${name##*/}
name=${name%.rpm}
printf '%s' "${name%.duplicate}"
MOCK
cat > "$work/bin/dnf" <<'MOCK'
#!/bin/bash
cat "$STRATA_VERIFY_FIXTURE/metadata"
MOCK
chmod +x "$work/bin/rpm" "$work/bin/dnf"
export PATH="$work/bin:$PATH" STRATA_REPO_DIR="$work/source" STRATA_VERIFY_FIXTURE="$work"
run() {
  local expected=$1 result=0
  "$repo/bin/strata-repo-verify" > "$work/output" 2>&1 || result=$?
  [[ $result == "$expected" ]] || { cat "$work/output"; exit 1; }
}
run 0
rg -q 'source package versions are valid' "$work/output"
sed -i 's/^strata-config\t.*/strata-config\t0:0.1.53-1.fc44/' "$work/metadata"
run 1
rg -q 'Wrong public version for strata-config' "$work/output"
cp "$work/metadata.good" "$work/metadata"
sed -i 's/^strata-lock-auth\t.*/strata-lock-auth\t0:0.1-1.fc44/' "$work/metadata"
run 1
rg -q 'Wrong public version for strata-lock-auth' "$work/output"
cp "$work/metadata.good" "$work/metadata"
touch "$work/source/packages/strata-config.duplicate.rpm"
run 1
rg -q 'Duplicate public RPM for strata-config' "$work/output"
rm "$work/source/packages/strata-config.duplicate.rpm"
truncate -s 104857601 "$work/source/packages/strata-config.rpm"
run 1
rg -q 'RPM exceeds' "$work/output"
truncate -s 0 "$work/source/packages/strata-config.rpm"
rm "$work/source/packages/zen-browser.rpm"
run 1
rg -q 'Required public RPM is missing from packages/: zen-browser' "$work/output"
touch "$work/source/packages/zen-browser.rpm"
sed -i '/^zen-browser\t/d' "$work/metadata"
run 1
rg -q 'Required package is missing from repository metadata: zen-browser' "$work/output"
echo 'PASS: publish gate accepts matching sources and rejects old versions, duplicate/oversized RPMs, missing files and incomplete metadata'
