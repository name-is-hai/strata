# Strata Snip

Strata Snip captures and annotates screenshots on Wayland and Hyprland. Press
Super+Shift+S to freeze the screen and choose **Region**, **App**, or **Monitor**
from the top toolbar. The X closes the picker. Captures use Strata's save,
clipboard, and clickable notification flow. The selected capture mode is
remembered in `~/.local/state/strata/snip-mode` for the next launch.

The picker freezes all active displays. Move to either display to select an
app or monitor, or use **Region** to drag across their shared edge. The screenshot
keeps the displays' actual desktop positions, including negative coordinates
and gaps. A shared canvas uses the highest display scale so mixed-scale captures
retain detail. Choosing Monitor waits for you to click a display (or press Enter); the current
display is highlighted before capture. Annotation
opens in the regular editor window after a multi-display selection.

The `strata-snip` executable is packaged with Strata. The desktop shortcut runs
`strata-capture-screenshot snip copy save`; `strata-edit-screenshot <file>`
opens an existing image in the annotation editor. The native command also
supports `--snip-toolbar`, `--capture-region`, `--capture-window`,
`--capture-fullscreen`, `--copy`, and `--save`.

`strata-open-image <file>` opens an independent image editor window. Several
images can stay open at once, and Super+Shift+S starts screenshot capture
without dismissing them. The shared capture lock applies only to overlays.
Image windows show a compact Shortcuts button at the bottom left instead of a
permanent reference card. Click it or press `?` to expand or collapse the
keyboard reference.
The screenshot selector also shows this compact guide as live UI alongside
its toolbar. Expanding it never changes the frozen image or the saved capture.
Toolbar tips wrap inside the editor and stay above its other controls.
The rotation buttons turn the whole image (Ctrl+R) or selected layers
(Ctrl+Shift+R) clockwise by 90 degrees. Both actions support undo/redo,
and saved working documents retain the rotation history.

The toolbar follows the active Strata palette in
`~/.local/state/strata/current/theme` and the system monospace font. Optional
capture settings live in `~/.config/strata/snip.conf`. Set
`STRATA_SCREENSHOT_DIR` to override the screenshot directory.

Build with `make build` and run native checks with `make check`. The original
project's feature guide and attribution are preserved in [UPSTREAM.md](UPSTREAM.md).

The capture toolbar also has **Record**. Enable it, choose **No audio**,
**Desktop**, **Microphone**, or **Desktop + mic**, and select a target. App
recording captures a fixed on-screen rectangle, so moving or covering the
window affects the video. Stop recording with **Super+Shift+R**. Recording
uses Strata’s existing `strata-capture-screenrecording` backend.
