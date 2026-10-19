One Strata keyboard feedback plugin: US/VN input methods, physical XKB
layouts, Caps Lock, and Num Lock. Service.qml owns the detectors and sends
all feedback through one OSD dispatcher. LockKeys.qml is an internal detector,
not a separately registered plugin.

Sources (MIT; notices retained in KEYGLOW-LICENSE and LOCK-KEYS-LICENSE):
- https://github.com/0x1ocean/omarchy-keyglow
  a3c949b323fc1f0bdce617b2f61bd7c16111fe6b
- https://github.com/trinity-bytes/omarchy-lock-keys-osd
  fab06ca0ddaa5e9ef5df771f6572e2b9cbc3e4e5

Fcitx5 remains the input engine; a shared 250ms observer detects US/VN
switches. Initial/repeated samples are silent. The lock detector follows
the first kernel LED source per lock, with Hyprland as its fallback.

Diagnostics: strata-shell keyboard-osd state
Tests: node --test scripts/tests/keyglow/*.test.js scripts/tests/lock-keys-osd.test.js
