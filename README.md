# Strata RPM repository

This is the static DNF repository for the personal Fedora-based Strata
desktop. It contains only Strata-built RPMs; Fedora itself supplies normal
desktop dependencies, and the tagged Quickshell package comes from its COPR.

## Install on a fresh Fedora 44 system

After this repository is published with GitHub Pages, run:

```bash
curl -fsSL https://name-is-hai.github.io/strata/bin/strata-install-desktop | \
  sudo bash -s -- --enable-greetd
```

Then, as the desktop user:

```bash
strata-apply-config
sudo reboot
```

The installer uses `install_weak_deps=False`, so Fedora does not add optional
Node/npm documentation solely because Neovim is installed.

## Strata update notifications

Strata checks its published DNF repository at startup and every six hours. A
notification and bar icon appear when newer installed Strata packages are
available. Click the icon or select **System → Update Strata** to review the
transaction in a terminal. DNF asks before installing anything.

```bash
strata-update --check  # Check now without installing
strata-update          # Review and install available Strata package updates
```

To publish an update, update the release versions and push a matching version
tag, such as `v1.0.0`. GitHub builds the RPMs, verifies the complete repository
and creates a draft release. Test it, then publish the draft to deploy its DNF
repository to Pages. Installed machines then detect the newer RPM versions.
See [Releasing Strata](docs/releasing.md) for the complete process and the
manual local-build alternative.

The checker uses Bash, RPM, DNF, jq, flock and a user cache. An offline check
retains the last result, and each set of available versions is notified once.
Existing custom bars can add the icon with
`strata-bar put strata.system-update --after strata.menu`; new installations
include it by default. Disable the **Strata updates** plugin to stop checks.
Run `scripts/tests/update-check.sh` to test with fake package commands.

## Diagnostics

Run `strata doctor` to check the installed desktop without changing settings.
From this checkout, use `bin/strata doctor`. Session checks work best in a
desktop terminal; unavailable session context is reported as skipped.

## Development hook

Install the repository hook once on a build machine:

```bash
prek install
```

When a staged RPM under `packages/` changes, the hook regenerates `repodata/`,
stages the new metadata, and verifies required Strata packages and versions.
It requires `createrepo_c`, DNF and `rpm-build` on the Fedora build machine.
