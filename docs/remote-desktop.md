# Remote access to the same Strata session

`strata-remote-desktop` is an optional, experimental integration with
[hypr-rdp](https://github.com/MuNeNiCK/hypr-rdp). It keeps the existing Hyprland
session and applications. It does not start a second desktop. It requires an
already logged-in Strata session; it cannot log in through greetd after reboot.

**This is screen blanking, not Windows RDP's secure console handoff.** Local
keyboards and mice are still attached to the running session. A person at the
computer can interfere with it, switch virtual terminals, or change its display
state. Do not rely on blanking to protect the session from physical access.
The ordinary session lock covers the remote display too; unlock it by entering
your Linux password through the RDP client. There is no password-bypass IPC.

## Install and connect

On the computer running Strata:

```bash
strata-remote-desktop setup
strata-remote-desktop credentials
strata-remote-desktop start
```

Setup downloads upstream **v0.1.7 for x86_64**, verifies the pinned SHA-256
checksum, and installs it under `~/.local/share/strata/remote-desktop`. It creates
a random RDP password, TLS certificate and private key under
`~/.config/strata/remote-desktop`, with private permissions. Existing settings
are never overwritten. RDP credentials differ from your Linux login password.
The optional setup needs `curl`, `openssl`, `tar` and `jq`. The downloaded
binary also needs Fedora's `libva`, `mesa-libgbm`, `pipewire-libs`, `pam` and
`libxkbcommon` libraries. Setup checks the binary can execute before writing
the final configuration. No additional compiler toolchain is installed.

The server listens on **127.0.0.1:3389**, and setup opens no firewall ports.
From the work computer, establish an SSH tunnel using the home computer's
NetBird address (replace `liam` and `HOME_NETBIRD_IP`):

```bash
ssh -N -L 13389:127.0.0.1:3389 liam@HOME_NETBIRD_IP
```

Leave that terminal running. Open **Remote Desktop Connection** on Windows
(`mstsc`) or **Remmina** on Linux. Connect using RDP to **127.0.0.1:13389** and
the credentials shown by `strata-remote-desktop credentials`. The home computer
must already accept SSH over NetBird. Setup does not configure SSH or NetBird.
You can inspect the server's certificate fingerprint on the home computer with:

```bash
openssl x509 -in ~/.config/strata/remote-desktop/cert.pem -noout -fingerprint -sha256
```

Start locks the local session before listening. Once the RDP connection is
authenticated, the integration pauses Strata's idle timers, prevents input from
waking physical displays, blanks those displays, and transfers occupied normal
workspaces to a Strata-owned 1920×1080 virtual display. Enter your normal Linux password at
Strata's lock screen to continue working with your existing windows.

On disconnect it secures the session lock **before** returning workspaces and
restoring physical DPMS and input-wake settings. Unlock locally to continue.
Workspace numbers are preserved where available; workspaces created remotely
return to the first available physical monitor. If the original monitor has
been unplugged, its windows also return to an available monitor.

The server inhibits automatic system sleep while running so it remains
reachable. It is a transient user service, not enabled automatically at login.
Its listening virtual display is kept alive until the service stops. If
recovery fails, it is retained so losing the last physical output does not
also destroy the virtual output. Existing
applications in special scratchpads remain in their scratchpads; only normal
occupied workspaces are transferred.

## Stop, inspect, or recover

```bash
strata-remote-desktop status
journalctl --user -u strata-remote-desktop.service -b
strata-remote-desktop stop
```

If a hook fails, the supervisor stops the RDP server and attempts recovery.
The per-session handoff journal is under
`$XDG_RUNTIME_DIR/strata-remote-desktop/`, and updates precede workspace moves.
If restoration cannot establish a secure lock, it leaves displays dark and
retains the journal. From SSH or a logged-in terminal in the same Hyprland
environment, retry:

```bash
strata-remote-desktop recover
```

Do not manually delete the handoff journal while recovery is pending. Stop the
service before changing display layout, reloading configuration or upgrading
Strata. The periodic blanking guard handles ordinary physical-screen wakeups,
but this integration is not a security boundary or a fix for compositor/driver
crashes during monitor removal. Keep an SSH connection available for initial
testing. Verify remote video, input, audio, disconnect restoration and local
unlock on the target machine before relying on it unattended.

To remove downloaded software and credentials after stopping successfully:

```bash
rm -r ~/.local/share/strata/remote-desktop ~/.config/strata/remote-desktop
```

The Strata command itself remains available with the config package. Nothing
adds a default RPM dependency on hypr-rdp, Xfce or GNOME.
