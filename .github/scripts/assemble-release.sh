#!/usr/bin/env bash
# Assemble CI build artifacts into the public runtime repository and release assets.
set -euo pipefail
cd "$(dirname -- "${BASH_SOURCE[0]}")/../.."
incoming=${1:?Usage: assemble-release.sh RPM_DIRECTORY}

declare -A expected selected
versions=$(for spec in packaging/*.spec; do
  rpmspec -q --qf $'%{NAME}\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}\n' "$spec" || exit 1
done)
while IFS=$'\t' read -r name evr; do expected[$name]=$evr; done <<< "$versions"
version=$(<VERSION)
for spec in strata-config hyprland-desktop hyprland-utilities; do
  [[ $(rpmspec -q --srpm --qf '%{VERSION}' "packaging/$spec.spec") == "$version" ]] || {
    echo "VERSION disagrees with $spec.spec" >&2; exit 1;
  }
done

while IFS= read -r -d '' file; do
  header=$(rpm -qp --qf $'%{NAME}\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}\t%{ARCH}' "$file")
  IFS=$'\t' read -r name evr arch <<< "$header"
  [[ -n ${expected[$name]:-} ]] || continue
  [[ $evr == "${expected[$name]}" && $arch =~ ^(x86_64|noarch)$ ]] || {
    echo "Unexpected build: $header ($file)" >&2; exit 1;
  }
  [[ -z ${selected[$name]:-} ]] || { echo "Duplicate build for $name" >&2; exit 1; }
  selected[$name]=$file
done < <(find "$incoming" -type f -name '*.rpm' -print0)

for name in "${!expected[@]}"; do
  [[ -n ${selected[$name]:-} ]] || { echo "Missing fresh build: $name" >&2; exit 1; }
done
rpm -K --nosignature "${selected[@]}"

# Retain legacy dependencies without source specs, such as strata-lock-auth.
# Remove superseded runtime RPMs by header name, never a filename prefix.
while IFS= read -r -d '' file; do
  name=$(rpm -qp --qf '%{NAME}' "$file")
  [[ -z ${selected[$name]:-} ]] || rm -- "$file"
done < <(find packages -maxdepth 1 -type f -name '*.rpm' -print0)
cp -- "${selected[@]}" packages/
rpm -K --nosignature packages/*.rpm
bin/strata-repo-refresh
bin/strata-repo-verify

output=build-output/release
mkdir -p "$output/site" "$output/assets"
cp -a packages repodata strata.repo VERSION LICENSE "$output/site/"
mkdir -p "$output/site/bin"
cp bin/strata-install-desktop "$output/site/bin/"
tar -C "$output/site" -czf "$output/assets/strata-repository-f44-x86_64.tar.gz" .
cp packages/*.rpm "$output/assets/"
(cd "$output/assets"; sha256sum -- *.rpm *.tar.gz > SHA256SUMS)
