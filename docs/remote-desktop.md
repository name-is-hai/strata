# Remote access to the same Strata session

Strata includes the Remmina RDP client and a checksum-verified
[hypr-rdp v0.1.7](https://github.com/MuNeNiCK/hypr-rdp/releases/tag/v0.1.7)
server. Update Strata on both computers. No separate tarball, dependency
installation or test script is needed.

The server reuses the existing Hyprland session and applications. A user must
already be logged in to Strata; RDP cannot log in through greetd after reboot.
Installing or updating Strata does not start the server or open a firewall port.

## Start the computer you want to control

On that computer, run:

```bash
strata-remote-desktop start
strata-remote-desktop credentials
```

First start creates a random RDP password and TLS certificate with private
permissions under `~/.config/strata/remote-desktop`. Existing credentials are
preserved. The backend is RPM-owned at `/usr/share/strata/rdp/hypr-rdp`.

Start locks the desktop before listening on **TCP port 3389 on all IPv4 and
IPv6 interfaces**. Any client that can reach the computer can connect using its
LAN address, NetBird address, or hostname. TLS and RDP password authentication
are required. No SSH connection or tunnel is needed.

On first start, `pkexec` requests administrator authorization to allow the
standard RDP service in firewalld's active and default zones, in both runtime
and permanent configuration. An inactive firewall is left inactive. The rule
remains for later starts; stopping RDP closes its listening socket.

Starting from an SSH administrative shell is also supported when a Strata
desktop is already running. SSH is only an optional way to manage the server.

Display credentials in your own terminal; do not share the password. The RDP
password is separate from the normal Linux login password.

## Connect from the other computer

Enter the server's address in Remmina, Windows Remote Desktop Connection, or
another RDP client. You can also open a saved Strata profile with:

```bash
strata-remote-desktop connect example.netbird.cloud
# Or prefill the remote username:
strata-remote-desktop connect remote-user@192.168.1.10
```

Strata opens Remmina with a private saved profile and keyboard capture enabled.
Hostnames, IPv4, bracketed IPv6 and an optional custom port are supported.
Profiles live under `~/.local/share/remmina`; repeated connections preserve
changes you make in Remmina. No personal hostname or credentials are shipped.

Enter the generated RDP password in Remmina and leave Domain empty. Once the
remote Strata lock screen appears, enter your normal Linux password there.
Remmina's **Grab all keyboard events** toolbar button toggles whether shortcuts
such as Super and Alt+Tab go to the remote desktop. The default toggle key is
Right Ctrl; you can change it in Remmina's keyboard preferences.

For NetBird names and addresses, both computers must be connected to NetBird,
and its access policy must permit TCP port 3389. Internet access through a
router also depends on that router's forwarding policy; Strata does not change
router or NetBird policy.

## Automatic video acceleration

Strata detects display-class PCI devices during desktop installation and
updates, installing Intel or AMD codec-enabled VA-API drivers as appropriate.
First RDP start also checks for missing drivers, covering machines upgraded
from an older installer. Package changes use administrator authorization and
the standard Fedora/RPM Fusion repositories. An unavailable repository or
declined optional driver installation does not prevent software RDP.

Before starting capture, Strata probes the render devices as the desktop user.
It checks the H.264 profile and encoding entrypoint used by the bundled backend,
then encodes three synthetic black frames. It never records the desktop for
this test. A successful test selects hardware-auto encoding at up to 60 FPS;
otherwise the default is software encoding at 30 FPS. Explicit `fps` and
`h264_backend` settings in the RDP configuration remain unchanged.

Driver presence or hardware decoding support alone does not qualify. In
particular, the current backend requires H.264 `EncSlice`; low-power-only
`EncSliceLP` devices and NVIDIA-only systems without a compatible VA-API encoder
remain on software. Existing NVIDIA display-driver and Secure Boot setup is
kept separate. Inspect the result with:

```bash
strata-video-acceleration probe
```

## What happens to the local desktop

Once the RDP connection is authenticated, Strata pauses its idle timers,
prevents input from waking physical displays, blanks those displays, and moves
occupied normal workspaces to an owned 1920×1080 virtual display. The original
window and workspace contents are retained; scratchpads remain scratchpads.
Both exact and indexed Hyprland virtual-output names are supported.

On disconnect, Strata locks the session before returning workspaces and
restoring physical display and input-wake settings. Unlock locally to continue.
If an original monitor was unplugged, its windows return to an available
physical display. Workspaces created remotely also return to a physical display.

**Blanking is not a secure local-console handoff.** Local keyboards and mice
remain attached. Someone at the computer can interfere with the running
session or change its display state. The normal session lock also covers the
remote display; there is no password-bypass IPC.

## Stop, inspect, or recover

```bash
strata-remote-desktop status
journalctl --user -u strata-remote-desktop.service -b
strata-remote-desktop stop
```

The server is an on-demand user service. It prevents automatic sleep while
running and is not enabled at login. Stop it before upgrading Strata or changing
display layout. Its virtual display is retained if recovery is pending.

If a hook fails, the supervisor stops the server and attempts recovery. The
handoff journal lives in `$XDG_RUNTIME_DIR/strata-remote-desktop/`; it records
moves before changing workspaces. If restoration cannot establish a secure
lock, it leaves displays dark and retains the journal. Stop the service and
retry from SSH or a terminal in that user's session:

```bash
strata-remote-desktop recover
```

Do not delete the handoff journal while recovery is pending. The periodic
blanking guard handles ordinary screen wakeups; it cannot prevent compositor
or graphics-driver crashes. Test video, input, audio, disconnect restoration
and local unlock before relying on an unattended machine.

After stopping successfully, deleting `~/.config/strata/remote-desktop` removes
the generated credentials. The client and server executables remain managed
by the Strata RPM and receive updates with Strata.
