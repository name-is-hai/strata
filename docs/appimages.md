# AppImages

Use **Install → Install AppImage** in the Strata menu and choose your downloaded
file, or run:

```bash
strata appimage install ~/Downloads/YourApp.AppImage
```

Strata copies the AppImage into `~/.local/bin`, creates a command and one app-menu
entry, and installs its bundled icon when available. The downloaded file is left
unchanged. There is no background Downloads watcher and installing does not start
the app. AppImages are executable software; use a download you trust.

The default ID comes from the bundled desktop filename. Override it or the
display name when needed:

```bash
strata appimage install ~/Downloads/YourApp.AppImage --id your-app --name "Your App"
```

The executable `~/.local/bin/your-app.AppImage` is the original app; the small
`~/.local/bin/your-app` launcher selects the appropriate launch path. Use the
command or app-menu entry. Strata refuses to overwrite existing files.

## Fonts

System font integration is enabled by default. Native GTK, Qt and other apps
inherit the normal desktop environment and font configuration. This does not
replace fonts globally or pin a particular Strata font family.

Apps that load bundled web fonts or hardcode a typeface can ignore those
preferences. There is no universal safe override for every AppImage. Strata
currently recognizes the ZaDark font layer and applies a targeted override to
ordinary UI and message text in an extracted copy, keeping icon fonts and the
original AppImage. The desktop UI font is resolved at each launch from GTK
settings, the desktop font setting, or fontconfig's distro default.
Other apps retain their own font behavior and may need their built-in font
setting or another adapter. The installer reports the applied behavior.

Restart the application after changing system fonts to refresh the override.
To preserve the original app's font
behavior instead:

```bash
strata appimage install ~/Downloads/YourApp.AppImage --font app
```

## Manage installed AppImages

```bash
strata appimage list
strata appimage remove your-app
```

**Remove → Remove AppImage** provides the same removal through a chooser.
Removal deletes the managed executable, launcher, icon, menu entry and extracted
copy. Application-owned profiles, account data and sign-ins are preserved.
Quit an app before removing it. To replace it with a newer download, remove the
managed installation first and install the new file; its profile remains.
