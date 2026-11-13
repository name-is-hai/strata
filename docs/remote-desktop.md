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

Start locks the desktop before listening on **127.0.0.1:3389**. It also works
through SSH when the user already has a running Strata session: the command
imports the desktop's Wayland display and Hyprland instance from the user
manager. For example, using your own SSH alias:

```bash
ssh my-laptop /usr/share/strata/bin/strata-remote-desktop start
```

Display credentials in your own terminal; do not share the password. The RDP
password is separate from the normal Linux login password.

## Connect from the other computer

Configure SSH access first, using a hostname, NetBird name or `~/.ssh/config`
alias. Then run:

```bash
strata-remote-desktop connect my-laptop
```

Strata opens Remmina with a private saved profile, an SSH tunnel to the target's
localhost RDP listener, the SSH username, port and configured identity file,
and keyboard capture enabled. It supports SSH public keys and ssh-agent.
Profiles live under `~/.local/share/remmina`; repeated connections preserve
changes you make in Remmina. No personal hostname or key is shipped by Strata.

Enter the generated RDP password in Remmina and leave Domain empty. Once the
remote Strata lock screen appears, enter your normal Linux password there.
Remmina's **Grab all keyboard events** toolbar button toggles whether shortcuts
such as Super and Alt+Tab go to the remote desktop. The default toggle key is
Right Ctrl; you can change it in Remmina's keyboard preferences.

From Windows or another RDP client, make an SSH tunnel manually:

```bash
ssh -N -L 13389:127.0.0.1:3389 my-laptop
```

Keep that terminal running and connect the RDP client to **127.0.0.1:13389**.
The target must already accept SSH; Strata does not configure SSH or NetBird.

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
