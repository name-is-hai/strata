# Strata RPM repository

This is the static DNF repository for the personal Fedora-based Strata
desktop. It contains only Strata-built RPMs; Fedora itself supplies normal
desktop dependencies, and the tagged Quickshell package comes from its COPR.

## Install on a fresh Fedora 44 system

After this repository is published with GitHub Pages, run:

```bash
curl -fsSLO https://name-is-hai.github.io/strata/scripts/strata-install
chmod +x strata-install
./strata-install --enable-sddm
```

Then, as the desktop user:

```bash
strata-apply-config
sudo reboot
```

The installer uses `install_weak_deps=False`, so Fedora does not add optional
Node/npm documentation solely because Neovim is installed.

## Repository layout

```text
packages/       Current Strata RPMs
repodata/       DNF metadata, regenerated after package changes
strata.repo     DNF repository definition
scripts/        Bootstrap and metadata-generation scripts
packaging/      RPM specs for Strata and its tagged Hyprland builds
config/         Strata-owned Hyprland, UWSM, and portal entry files
shell/           Quickshell desktop UI
bin/, systemd/   Strata runtime commands and user services
```

## Publishing

1. Create the public GitHub repository `name-is-hai/strata`.
2. Push this directory's `main` branch.
3. In GitHub repository settings, set Pages source to **GitHub Actions**.
4. The included workflow generates `repodata` and publishes the repository at
   `https://name-is-hai.github.io/strata/`.

Before adding a newly built RPM, remove its older package version from
`packages/`, run `scripts/refresh-repodata.sh`, then run
`scripts/verify-repo.sh`. DNF metadata should contain one current build of
each package.

The repository is not RPM-signed yet, so `gpgcheck=0` is intentional for this
personal bootstrap repository. Add an RPM signing key before sharing it with
other users.
