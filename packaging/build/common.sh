#!/usr/bin/env bash
# Shared compiler/dependency setup and RPM invocation. Changes rebuild all targets.
set -euo pipefail

topdir=/build/rpmbuild
mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SRPMS}

# A direct official endpoint is an opt-in escape hatch for a stale or
# unreachable metalink mirror. Normal builds keep Fedora mirror choice.
if [[ -n ${STRATA_FEDORA_RELEASE_BASEURL:-} ]]; then
  sed -ri "/^(metalink|mirrorlist)=/d" /etc/yum.repos.d/fedora.repo
  sed -ri "0,/^#baseurl=/s|^#baseurl=.*|baseurl=${STRATA_FEDORA_RELEASE_BASEURL}|" /etc/yum.repos.d/fedora.repo
fi
if [[ -n ${STRATA_FEDORA_UPDATES_BASEURL:-} ]]; then
  sed -ri "/^(metalink|mirrorlist)=/d" /etc/yum.repos.d/fedora-updates.repo
  sed -ri "0,/^#baseurl=/s|^#baseurl=.*|baseurl=${STRATA_FEDORA_UPDATES_BASEURL}|" /etc/yum.repos.d/fedora-updates.repo
fi

dnf install -y --setopt=install_weak_deps=False \
  rpm-build rpmdevtools dnf-plugins-core createrepo_c jq
cp -a /src/packaging/. "$topdir/SOURCES/"

# Only copy sources into RPM archives. Local builds and imported themes
# can carry large caches or nested Git histories that are not package data.
copy_source_tree() {
  tar -C /src --exclude=.git --exclude=__pycache__ --exclude="*.py[cod]" \
    --exclude=target --exclude=third_party/strata-snip/build \
    --exclude=third_party/strata-snip/stage -cf - "$@" |
    tar -C "$source_root" -xf -
}

built_specs=()

build_spec() {
  local spec=$1 recipe=${2:-} build_key completed
  build_key="$spec"
  for completed in "${built_specs[@]}"; do
    [[ $completed != "$build_key" ]] || return 0
  done
  if [[ -n $recipe ]]; then source "/src/$recipe"; fi
  # -R derives the directory from RPM _sourcedir. Local Source0 is already
  # generated for Strata; spectool fetches its pinned upstream archives.
  spectool -g -R -d "_topdir $topdir" "/src/packaging/$spec"
  dnf builddep -y --setopt=install_weak_deps=False "/src/packaging/$spec"
  rpmbuild -ba "/src/packaging/$spec" --define "_topdir $topdir"
  built_specs+=("$build_key")
}

