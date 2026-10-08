# Strata configuration

Versioned desktop defaults for the Fedora-based Strata desktop.

The RPM installs immutable defaults and the canonical shell below
`/usr/share/strata`. For compatibility, the package generates
`/usr/share/quickshell/strata` from the same source using hard links, so the
files occupy space only once. It does not replace files in a user's home
directory. Run this command once after installation:

```console
strata-apply-config
```

The command installs only missing user entry files and links the packaged
Quickshell configuration. Existing user files are left unchanged. Use
`strata-apply-config --dry-run` to preview changes or
`strata-apply-config --force` when you deliberately want to replace managed
files; backups are saved with a timestamp.

## Current defaults

- Hyprland launched as a UWSM session
- Ghostty on `SUPER+T`
- Close window on `SUPER+Q`
- Nautilus on `SUPER+F`
- Default browser on `SUPER+B`
- Quickshell launcher on `SUPER+/`
- Quickshell system menu on `SUPER+ESCAPE`
- Native Quickshell notification center
- Native clipboard history and emoji picker
- Screenshot selection on `PRINT`

The initial Quickshell release provides the bar, workspaces, tray, clock,
application launcher, system menu, notification center, clipboard history,
emoji picker, and keybinding help.

## Source layout

The unified Strata repository contains both source and the published DNF
repository. `packaging/strata-config.spec` maps the desktop source as follows.

| Source                          | Installed path                       |
| ------------------------------- | ------------------------------------ |
| `bin/`                          | `/usr/share/strata/bin`              |
| `shell/`                        | `/usr/share/strata/shell`            |
| `runtime-config/`               | `/usr/share/strata/config`           |
| `runtime-default/` + `default/` | `/usr/share/strata/default`          |
| `themes/`                       | `/usr/share/strata/themes`           |
| `docs/`                         | `/usr/share/strata/docs`             |
| `runtime-version`               | `/usr/share/strata/version`          |
| `config/hypr`, `config/uwsm`, `config/xdg-desktop-portal` | `/usr/share/strata/user-config` |
| `scripts/`                      | `/usr/bin`                           |

`default/` holds the Hyprland defaults and `config/` holds the per-user entry
files, so the runtime payload is kept in `runtime-default/` and
`runtime-config/` to avoid colliding with them.

Personal Ghostty, Neovim, Zsh, Tmux, Git, Fcitx5, Zed, and Mise settings are
kept in the separate `dotfiles` repository and are never packaged by Strata.
