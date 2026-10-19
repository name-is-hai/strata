# Swatch for Strata

Strata's default theme picker is adapted from [Jordan McKible's Swatch](https://github.com/jmckible/omarchy-swatch), upstream version 0.4.0, commit `4b87baf78e914858f132bd33dad0734481284ab1`. The MIT license and original attribution are preserved; the bundled plugin ID is `strata.theme-picker`. This directory contains the runtime and focused tests; upstream demonstration media is not bundled.

Run `strata-theme-select`, or select Style → Themes & backgrounds. Browse themes with Left/Right, backgrounds with Up/Down, Enter to apply, Escape to cancel and restore the previous shell palette. Press Space or `/` to search, `f` to favorite, Ctrl+F to filter favorites, Delete to hide a background, Ctrl+Z to undo hiding, and Ctrl+H to show hidden backgrounds.

The picker previews wallpapers and shell colors without applying the theme until confirmation. It uses Strata's theme commands and directories directly. Generated previews live in `${XDG_CACHE_HOME:-~/.cache}/strata/swatch`; favorites and hidden backgrounds live in `${XDG_STATE_HOME:-~/.local/state}/strata/swatch/preferences.json`. Collection actions never modify theme files or desktop configuration.

Theme navigation restores each theme's last chosen wallpaper from Strata's `theme-backgrounds` state. Full-screen previews use uncropped derivatives, bounded native-size metadata, and the same saved per-monitor position, zoom and fit geometry as the desktop. Applying waits for the desktop image to become ready before lifting the picker cover, so it does not reveal a centered image that then moves into place.

Every opening starts on the live theme. Each theme lists only its own wallpapers and restores its own remembered choice, independently of the current desktop wallpaper. Desktop double-click opens theme + background mode: confirmation applies the selected theme and its selected wallpaper together. Right double-click directly opens full-screen wallpaper adjustment: drag to reposition, scroll to zoom, Enter to save, Escape to cancel. `strata-theme-bg-switcher` uses `pick.sh --background` to return a selected wallpaper path without applying it; cancellation exits 1 with no selection. `strata-theme-bg-cache` warms this picker's index and derivatives.

There is no Python runtime or helper. Indexing and application use Bash, jq and ImageMagick. Perl performs descriptor-bound, no-follow file reads. `preferences.sh` uses jq for schema validation and transformations, with Perl file descriptors, a read-only script lock, bounded reads, exclusive temporary creation, fsync and atomic replacement for durable state. Invalid files are refused without replacing them.

Strata's normal wallpaper handoff is supported. Omarchy's compositor boot-intro protocol is absent; the landing probe follows Strata's current-background link. Optional video previews remain isolated in `VideoStage.qml` so a missing QtMultimedia module cannot prevent still-image previews.

Tests:

`bash scripts/tests/image-tools.sh` checks ImageMagick previews in the supported raster formats, menu thumbnail crops and the screenshot fallback without desktop interaction.

```sh
node shell/plugins/theme-picker/test/model.test.js
bash shell/plugins/theme-picker/test/preferences.sh
bash shell/plugins/theme-picker/test/background.sh
bash shell/plugins/theme-picker/test/current-selection.sh
bash shell/plugins/theme-picker/test/framing.sh
bash shell/plugins/theme-picker/test/hostile.sh
```

QML changes require a shell restart. Verify loading through `strata-shell shell call strata.theme-picker curationStatus ''`; this does not open the picker. Keep the upstream bounded snapshot and derivative-only rendering rules when updating the port.
