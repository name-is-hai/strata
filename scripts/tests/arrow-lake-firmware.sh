#!/usr/bin/env bash
# Isolated CPU fixtures and DNF recorder; never install packages on the host.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-arrow-lake.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
eval "$(awk '/^has_intel_arrow_lake_hardware\(\)/,/^}/' "$repo/bin/strata-install-desktop")"
eval "$(awk '/^install_intel_arrow_lake_firmware\(\)/,/^}/' "$repo/bin/strata-install-desktop")"
dnf() { printf '%s\n' "$@" >>"$work/dnf"; }
cpu() {
  printf 'vendor_id\t: %s\ncpu family\t: %s\nmodel\t\t: %s\nmodel name\t: %s\n\n' "$1" "$2" "$3" "${4:-CPU}" >"$work/cpuinfo"
}
for model in 181 197 198; do
  cpu GenuineIntel 6 "$model"
  has_intel_arrow_lake_hardware "$work/cpuinfo"
  : >"$work/dnf"
  install_intel_arrow_lake_firmware "$work/cpuinfo"
  printf '%s\n' install -y --setopt=install_weak_deps=False alsa-sof-firmware alsa-ucm iwlwifi-mld-firmware >"$work/expected"
  cmp "$work/expected" "$work/dnf"
done
for other in 'GenuineIntel 6 189' 'GenuineIntel 6 183' 'AuthenticAMD 6 197' 'GenuineIntel 15 197'; do
  read -r vendor family model <<<"$other"
  cpu "$vendor" "$family" "$model" 'Intel Corporation Arrow Lake'
  if has_intel_arrow_lake_hardware "$work/cpuinfo"; then echo 'False hardware match' >&2; exit 1; fi
  : >"$work/dnf"
  install_intel_arrow_lake_firmware "$work/cpuinfo"
  [[ ! -s $work/dnf ]]
done
printf 'processor\t: 0\nCPU architecture: 8\n' >"$work/cpuinfo"
if has_intel_arrow_lake_hardware "$work/cpuinfo"; then exit 1; fi
printf 'PASS: Arrow Lake U/H/desktop package install; other Intel, AMD and non-x86 CPUs excluded\n'
