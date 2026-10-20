#!/usr/bin/env bash
# Target dispatch and artifact collection; compiler behavior lives in common.sh.
set -euo pipefail
source /src/packaging/build/common.sh
mapfile -t all_targets < <(jq -er 'keys[]' /src/packaging/build/targets.json)
mkdir -p /out/RPMS /out/SRPMS
for requested in $STRATA_TARGETS; do
  if [[ $requested == all ]]; then selected=("${all_targets[@]}"); else selected=("$requested"); fi
  for target in "${selected[@]}"; do
    spec=$(jq -er --arg target "$target" '.[$target].spec' /src/packaging/build/targets.json)
    recipe=$(jq -r --arg target "$target" '.[$target].recipe // empty' /src/packaging/build/targets.json)
    build_spec "$spec" "$recipe"
    # Keep completed packages even if a later target fails.
    cp -a "$topdir/RPMS/." /out/RPMS/
    cp -a "$topdir/SRPMS/." /out/SRPMS/
  done
done
