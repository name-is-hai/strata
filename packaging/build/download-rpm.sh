#!/usr/bin/env bash
# Download one pinned, independently released RPM. Never compile a fallback.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
target=${1:?Usage: download-rpm.sh TARGET OUTPUT_DIRECTORY}
output=${2:?Usage: download-rpm.sh TARGET OUTPUT_DIRECTORY}
definition=$(jq -ce --arg target "$target" '.[$target].release' "$root/packaging/build/targets.json")
repository=$(jq -er .repository <<< "$definition")
tag=$(jq -er .tag <<< "$definition")
asset=$(jq -er .asset <<< "$definition")
[[ $repository =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && $tag =~ ^v[0-9][A-Za-z0-9_.-]*$ && $asset =~ ^[A-Za-z0-9][A-Za-z0-9+_.~-]*\.rpm$ ]]
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
base="https://github.com/$repository/releases/download/$tag"
for file in SHA256SUMS "$asset"; do
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 \
    --max-time 300 "$base/$file" --output "$temporary/$file"
done
# Select exactly the expected asset; never execute paths from a remote manifest.
checksum=$(awk -v file="$asset" '$2 == file {print $1}' "$temporary/SHA256SUMS")
[[ $checksum =~ ^[a-f0-9]{64}$ ]] || { echo "Missing or ambiguous checksum for $asset" >&2; exit 1; }
(cd "$temporary"; printf '%s  %s\n' "$checksum" "$asset" | sha256sum --check --strict -)
mkdir -p "$output"
cp -- "$temporary/$asset" "$output/$asset"
printf 'Downloaded %s from %s %s\n' "$asset" "$repository" "$tag"
