#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

command -v createrepo_c >/dev/null 2>&1 || {
  echo "createrepo_c is required (install the createrepo_c package)." >&2
  exit 1
}

package_list=$(mktemp)
trap 'rm -f "$package_list"' EXIT
find packages -maxdepth 1 -type f -name '*.rpm' -print >"$package_list"

test -s "$package_list" || {
  echo "No RPMs found in $repo_root/packages." >&2
  exit 1
}

# The repository root contains build-output/ for local use. Index the root so
# metadata keeps package locations as packages/<name>.rpm, but explicitly list
# the public RPM directory to prevent duplicate build artifacts from leaking
# into the DNF repository.
createrepo_c --checksum sha256 --pkglist "$package_list" .
