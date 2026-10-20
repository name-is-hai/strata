#!/usr/bin/env bash
# Prepare only the config/casting source archive. Sourced by build_spec.
version=$(rpmspec -q --srpm --qf "%{VERSION}" /src/packaging/strata-config.spec)
source_root="/tmp/strata-config-${version}"
rm -rf "$source_root"
mkdir -p "$source_root"
copy_source_tree LICENSE bin config defaults docs native packaging/casting \
  runtime-version scripts shell systemd third_party
# Themes are optional: a minimal Strata checkout can intentionally omit
# all bundled artwork and terminal-theme templates.
[[ -e /src/themes ]] && copy_source_tree themes
tar -C /tmp -czf "$topdir/SOURCES/strata-config-${version}.tar.gz" "strata-config-${version}"
