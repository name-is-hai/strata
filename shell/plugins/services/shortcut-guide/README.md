Strata Shortcut Guide is adapted from cyprusad/omakeez (MIT; see LICENSE).
https://github.com/cyprusad/omakeez
Source revision: 02817f97021c264fc254f862e66bb36edafd2f8c

Hold Super for 500ms to see a visual guide on the focused display. Add Shift,
Ctrl, or Alt to narrow it. Release Super to dismiss it. Quick shortcuts,
fullscreen applications, the lock screen, and Strata Polkit prompts keep the
guide hidden. The guide takes no keyboard focus and does not redirect key presses.
Pressing another key, clicking a mouse button, or scrolling cancels the guide
for that hold. It stays dismissed until the starting modifier is released.
Holding a mouse button before the modifier also keeps the guide hidden.
Screenshot capture hides the guide and reminders before freezing pixels;
they remain suppressed while the Strata Snip capture surface is open.

Tools → Toggle → Shortcut Guide enables or disables it.
Settings → Shortcut Guide opens its settings panel. Changes save immediately.
The guide uses its default top-edge layout; reminders default to the center. The persistent
configuration is ~/.config/strata/shortcut-guide.json:

    {"enabled":true,"guideDelayMs":500,"showInFullscreen":false}

Optional properties: guideTopOffset (0–320), guideSuperEnabled (default true),
guideShiftEnabled, guideCtrlEnabled, guideAltEnabled (default false).
The Lua observer becomes inert while disabled. It uses Hyprland events and
never opens /dev/input. A short-lived Python catalog generator reads Hyprland
bindings and the XKB keymap at startup/configuration changes; it is not a
keyboard-watching daemon. Generated state lives in
~/.local/state/strata/shortcut-guide/.

Strata installs the bridge through its packaged input defaults. It does not
edit the user's Hyprland configuration. There is no additional bar icon.
Diagnostics: strata-shell shortcut-guide diagnostics
Toggle from a terminal: strata-shortcut-guide [toggle|on|off|status]

Shortcut reminders are adapted from ForrestKnight/omarchy-key-promoter
(MIT; see KEY-PROMOTER-LICENSE):
https://github.com/ForrestKnight/omarchy-key-promoter
Source revision: 21c2b7184a33d800132ac2b6fb66aa31ae70de9a
When a menu selection has a matching shortcut, a themed toast teaches it.
The first-party menu reports the selection directly. There is no process scan,
cgroup watcher, usage history, or guessed launch attribution. Dismissing the
menu does not cause a reminder. Set promoterEnabled to false to disable only
these reminders; the menu's master toggle controls both features.

The desktop guide and shortcut toast animate their live contents in QML.
Their layer surfaces do not use compositor animations, so capture preparation
can unmap them immediately without retaining a faded snapshot. The screenshot
command has no animation delay. Once the desktop is frozen, Strata Snip draws
its own interactive Shortcuts guide above the image; it is never exported.
