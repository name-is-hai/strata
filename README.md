# Strata RPM repository

This is the static DNF repository for the personal Fedora-based Strata
desktop. It contains only Strata-built RPMs; Fedora itself supplies normal
desktop dependencies, and the tagged Quickshell package comes from its COPR.

## Install on a fresh Fedora 44 system

After this repository is published with GitHub Pages, run:

```bash
curl -fsSL https://name-is-hai.github.io/strata/scripts/strata-install | \
  sudo bash -s -- --enable-sddm
```

Then, as the desktop user:

```bash
strata-apply-config
sudo reboot
```

The installer uses `install_weak_deps=False`, so Fedora does not add optional
Node/npm documentation solely because Neovim is installed.

## Development hook

Install the repository hook once on a build machine:

```bash
prek install
```

When a staged RPM under `packages/` changes, the hook regenerates `repodata/`,
stages the new metadata, and verifies that DNF can resolve the required Strata
packages. It requires `createrepo_c` and `dnf` on that build machine.
