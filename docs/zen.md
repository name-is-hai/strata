# Zen Browser

Zen is optional. When a user chooses it, Strata installs the official Linux tarball into
`~/.tarball-installations/zen`, following Zen's
[per-user installation layout](https://docs.zen-browser.app/guides/install-linux).
The application files belong to the desktop user, so Zen's built-in updater
can replace them without root permissions or a new Strata release.
Browser updates may require restarting Zen to take effect.

## Installation

Strata does not download Zen at login or during user configuration. Choose
**Install Zen Browser** from the application menu, or run as the desktop user:

```bash
strata-install-browser zen
```

The underlying installer is also available directly:

```bash
strata-install-zen
```

The installer asks sudo to install any missing native Fedora libraries and
`xz` for extraction. Those packages are not mandatory Strata dependencies.
Users choosing other browsers do not install them for Zen.

This downloads the latest official release only when Zen is absent. Later
installer runs preserve the installed version, including self-updates.
Use `strata-install-zen --force` to download and replace the application again.
Failed or incomplete downloads leave the previous application intact.

Use `strata-launch-browser` to open whichever browser is set as the system
default, including a choice made inside a browser. Selecting Zen with
`strata-default-browser zen` installs it first if needed, then updates the XDG
default. Zen’s own `zen` and `zen-browser` commands are created in `~/.local/bin`
when no custom command exists.
The primary desktop ID is `zen.desktop`. A hidden `zen-browser.desktop` alias
keeps MIME defaults from the former RPM installation working. Custom user
launchers are preserved. No default-browser preference is changed automatically.

## Existing RPM installations

First upgrade to the Strata packages containing this migration, including
`hyprland-desktop-1.1.1-2` or newer. Those packages no longer require Zen RPMs,
and do not install Zen libraries for users who choose other browsers.
If you want to migrate your Zen installation, close Zen and run:

```bash
strata-install-zen
~/.local/bin/zen
```

Profiles under `~/.config/zen` (or `$XDG_CONFIG_HOME/zen`) and `~/.zen` are
left untouched. Because moving an application can change its per-installation
profile identity, the launcher explicitly reuses a single native profile or
one marked as the default. It honors explicit `--profile` and profile-manager
arguments. With several profiles and no clear default, select the existing
profile through Zen's profile manager; the migration does not guess.

After verifying the browser and migrating every desktop user, the old system
RPMs can be removed. Review DNF's transaction before confirming:

```bash
sudo dnf remove --no-autoremove zen-browser zen-browser-engine
```

Strata does not erase these RPMs automatically, remove another user's browser,
rewrite profile configuration, or delete browsing data. The project no longer
builds or publishes either Zen RPM. Flatpak installations and profiles remain
separate and are not migrated by these commands.
