#!/usr/bin/env bash
# Exercise publication gates with isolated RPM headers and DNF metadata mocks.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-repo-verify-test.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/source/bin" "$work/source/packaging" "$work/source/packages" "$work/source/repodata"
cp "$repo"/packaging/*.spec "$work/source/packaging/"
mkdir -p "$work/source/packaging/build"
cp "$repo/packaging/build/targets.json" "$work/source/packaging/build/"
touch "$work/source/bin/strata" "$work/source/repodata/repomd.xml"
for spec in "$repo"/packaging/*.spec; do
  rpmspec -q --qf $'%{NAME}\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}\n' "$spec"
done > "$work/metadata.good"
jq -r 'to_entries[] | select(.value.release) | .value.release | [.name, .evr] | @tsv' "$repo/packaging/build/targets.json" >> "$work/metadata.good"
while IFS=$'\t' read -r name version; do touch "$work/source/packages/$name.rpm"; done < "$work/metadata.good"
cp "$work/metadata.good" "$work/metadata"
cat > "$work/bin/rpm" <<'MOCK'
#!/bin/bash
[[ $1 == -K ]] && exit 0
name=${@: -1}
name=${name##*/}
name=${name%.rpm}
if [[ $* == *EPOCHNUM* ]]; then
  awk -F '\t' -v name="$name" '$1 == name {printf "%s\t%s\tx86_64", $1, $2}' "$STRATA_VERIFY_FIXTURE/metadata.good"
  exit 0
fi
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
sed -i 's/^celluloid\t.*/celluloid\t1:0.30-3.fc44/' "$work/metadata"
run 1
rg -q 'Wrong public version for celluloid' "$work/output"
cp "$work/metadata.good" "$work/metadata"
touch "$work/source/packages/strata-config.duplicate.rpm"
run 1
rg -q 'Duplicate public RPM for strata-config' "$work/output"
rm "$work/source/packages/strata-config.duplicate.rpm"
truncate -s 104857601 "$work/source/packages/strata-config.rpm"
run 1
rg -q 'RPM exceeds' "$work/output"
truncate -s 0 "$work/source/packages/strata-config.rpm"
rm "$work/source/packages/ghostty.rpm"
run 1
rg -q 'Required public RPM is missing from packages/: ghostty' "$work/output"
touch "$work/source/packages/ghostty.rpm"
sed -i '/^ghostty\t/d' "$work/metadata"
run 1
rg -q 'Required package is missing from repository metadata: ghostty' "$work/output"

# Exercise the actual assembly script as well: imported RPMs have no local
# spec and must still reach packages/, metadata, release assets and the tarball.
cp "$work/metadata.good" "$work/metadata"
mkdir -p "$work/source/.github/scripts"
cp "$repo/.github/scripts/assemble-release.sh" "$work/source/.github/scripts/"
cp "$repo/.github/release-notes.md" "$work/source/.github/"
cp "$repo/"{VERSION,runtime-version,LICENSE,strata.repo} "$work/source/"
cp "$repo/bin/"{strata-cmd-repo-root,strata-release-version,strata-repo-refresh,strata-repo-verify,strata-install-desktop} "$work/source/bin/"
cp -a "$work/source/packages" "$work/source/incoming"
cat > "$work/bin/createrepo_c" <<'MOCK'
#!/bin/bash
mkdir -p repodata
touch repodata/repomd.xml
MOCK
chmod +x "$work/bin/createrepo_c"
bash "$work/source/.github/scripts/assemble-release.sh" incoming > "$work/output" 2>&1 || { cat "$work/output"; exit 1; }
test -f "$work/source/packages/celluloid.rpm"
test -f "$work/source/build-output/release/assets/celluloid.rpm"
tar -tzf "$work/source/build-output/release/assets/strata-repository-f44-x86_64.tar.gz" | rg -q '^./packages/celluloid.rpm$'
echo 'PASS: publish gates reject invalid RPM sets; assembly includes imported Celluloid in repository and release archive'
