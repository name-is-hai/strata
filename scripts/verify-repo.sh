#!/usr/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo_url="file://$repo_root"

test -f "$repo_root/repodata/repomd.xml" || {
  echo "Missing repodata/repomd.xml. Run scripts/refresh-repodata.sh first." >&2
  exit 1
}

dnf -q --disablerepo='*' \
  --repofrompath=strata-test,"$repo_url" \
  --enablerepo=strata-test \
  repoquery --qf '%{name}-%{version}-%{release}.%{arch}' \
  strata-config hyprland-desktop hyprland-desktop-core hyprland-desktop-services \
  >/dev/null

echo "Strata repository metadata and required packages are valid."
