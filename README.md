# Strata RPM repository

This is the static DNF repository for the personal Fedora-based Strata
desktop. It contains only Strata-built RPMs; Fedora itself supplies normal
desktop dependencies, and the tagged Quickshell package comes from its COPR.

## Install on a fresh Fedora 44 system

After this repository is published with GitHub Pages, run:

```bash
curl -fsSL https://name-is-hai.github.io/strata/scripts/strata-install | \
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

To publish an update, increase `Version` or `Release` in
`packaging/strata-config.spec`, build with `scripts/build-rpms-podman config`,
and publish the new RPM from `build-output/RPMS/` under `packages/` on `main`.
The Pages workflow regenerates `repodata/` and publishes the repository. Machines
then detect the newer RPM version; pushing source changes or a GitHub tag alone
does not publish an installable update.

The checker uses Bash, RPM, DNF, jq, flock and a user cache. An offline check
retains the last result, and each set of available versions is notified once.
Existing custom bars can add the icon with
`strata-bar put strata.system-update --after strata.menu`; new installations
include it by default. Disable the **Strata updates** plugin to stop checks.
Run `scripts/tests/update-check.sh` to test with fake package commands.

## Development hook

Install the repository hook once on a build machine:

```bash
prek install
```

When a staged RPM under `packages/` changes, the hook regenerates `repodata/`,
stages the new metadata, and verifies that DNF can resolve the required Strata
packages. It requires `createrepo_c` and `dnf` on that build machine.
