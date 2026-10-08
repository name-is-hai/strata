#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

command -v createrepo_c >/dev/null 2>&1 || {
  echo "createrepo_c is required (install the createrepo_c package)." >&2
  exit 1
}

find packages -maxdepth 1 -type f -name '*.rpm' -print -quit | grep -q . || {
  echo "No RPMs found in $repo_root/packages." >&2
  exit 1
}

exec createrepo_c --update --checksum sha256 .
