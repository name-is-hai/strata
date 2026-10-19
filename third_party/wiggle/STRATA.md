# Strata integration

Upstream: https://github.com/sanjyay/wiggle
Revision: 03524f9052434a5fd7d09b35d49a53350c496788 (1.1.1)
License: MIT; upstream attribution is retained.

The RPM builds the C monitor from source and installs it as strata-wiggle-monitor.
The standard-library-only cursor extractor is strata-wiggle-discover-cursor.
The service lives in shell/plugins/services/wiggle, enabled as strata.wiggle.
There is no upstream precompiled binary in this source snapshot.

Mouse/touchpad active-seat uaccess replaces Omarchy's input-group provisioning.
Keyboard-capable nodes are rejected, even if they advertise relative axes.
The service restores the cursor on helper failure and does not activate while
Strata's lock is secure or requested. Asset refreshes run every 30 seconds. Repeated shakes are capped at 8×.
The monitor command pipe is explicitly enabled for Quickshell 0.3.1.
Lifecycle tests verify native-cursor restoration using private fake IPC sockets.

Disable using: strata-shell shell setPluginEnabled strata.wiggle false
Enable using: strata-shell shell setPluginEnabled strata.wiggle true

Touchpad support reads absolute contact positions, normalized by axis resolution.
Only one-finger motion contributes to a per-device shake history. Finger lifts,
tracking-ID changes, and multi-finger contacts reset the history. Direct
touchscreens remain excluded. Unit tests use libevdev fixtures without sending
real compositor gestures.
