#!/usr/bin/env bash
# Optional previous-release download. Any failure leaves a full-build baseline.
set -euo pipefail
destination=build-output/reuse-base
mkdir -p "$destination"
if [[ ${FORCE_FULL:-false} == true ]]; then exit 0; fi

download() {
  gh release list --exclude-drafts --exclude-pre-releases --limit 100 \
    --json tagName,publishedAt > "$destination/releases.json" || return 1
  previous=$(node -e '
    const fs=require("fs");
    const releases=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
    const prior=releases.filter(r=>r.tagName!==process.env.TAG)
      .sort((a,b)=>b.publishedAt.localeCompare(a.publishedAt))[0];
    if(prior)process.stdout.write(prior.tagName);
  ' "$destination/releases.json") || return 1
  [[ -n $previous ]] || return 1
  echo "Checking reusable RPMs from $previous"
  gh release download "$previous" --dir "$destination" \
    --pattern strata-repository-f44-x86_64.tar.gz --pattern SHA256SUMS \
    --pattern release-manifest.json || return 1
  (
    cd "$destination"
    grep -E '^[a-f0-9]{64}  (strata-repository-f44-x86_64.tar.gz|release-manifest.json)$' SHA256SUMS > baseline.sha256
    [[ $(wc -l < baseline.sha256) == 2 ]] || exit 1
    sha256sum -c baseline.sha256
  ) || return 1
  tar --no-same-owner -xzf "$destination/strata-repository-f44-x86_64.tar.gz" \
    -C "$destination" ./packages || return 1
}

if ! download; then
  echo 'Previous release could not be verified; all targets will be built.'
  rm -rf "$destination"
  mkdir -p "$destination"
fi
