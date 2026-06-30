# KDE Connect — Setup & Usage

Phone integration (notifications, clipboard, files, calls) for Guix System + Niri.

## How it's configured

| File | Change |
|---|---|
| `src/raynet-guix/packages/base-utils.scm` | `kdeconnect` added to `system-tools` via `(gnu packages kde-internet)` |
| `src/raynet-guix/users/orka/files/.config/niri/config.kdl` | `spawn-at-startup "kdeconnect-indicator"` launches daemon + tray icon at login |

The daemon starts automatically on every Niri session. No manual service management needed.

## First-time pairing

1. Install **KDE Connect** on your phone:
   - Android: Google Play / F-Droid (`org.kde.kdeconnect_tp`)
   - iOS: App Store

2. Ensure phone and PC are on the **same Wi-Fi network**.

3. Open settings on the PC:
   ```bash
   kdeconnect-settings
   ```

4. Your phone appears in the device list — click **Request Pairing**, then accept on the phone.

## Daily usage

### CLI reference

```bash
# List paired devices
kdeconnect-cli -l

# Ping a device (connectivity check)
kdeconnect-cli --ping --name "YourPhone"

# Send a file to the phone
kdeconnect-cli --share /path/to/file --name "YourPhone"

# Mount phone storage via SFTP (uses sshfs)
kdeconnect-cli --mount --name "YourPhone"

# Ring the phone
kdeconnect-cli --ring --name "YourPhone"

# Send a text (SMS, Android only)
kdeconnect-cli --send-sms "message" --destination "+1234567890" --name "YourPhone"

# Run a command on the PC from the phone (must be set up in kdeconnect-settings first)
kdeconnect-cli --list-commands --name "YourPhone"
```

### GUI

Right-click the KDE Connect tray icon in DankMaterialShell for a quick menu (send file, ring, clipboard, etc.).

Open full settings:
```bash
kdeconnect-settings
```

### Features that work automatically after pairing

| Feature | Notes |
|---|---|
| Phone notifications on desktop | Via D-Bus (`org.freedesktop.Notifications`) → DankMaterialShell |
| Clipboard sync (bidirectional) | Handled by `wl-clipboard` (already installed) |
| Media control from phone | Pause/play/skip desktop media via the phone app |
| Battery level in tray | Phone battery shown in the KDE Connect tray icon tooltip |

## Troubleshooting

**Device not discovered:**
- Confirm both devices are on the same subnet.
- Run `kdeconnect-indicator &` in a terminal to ensure the daemon is running.
- Check the daemon is alive: `kdeconnect-cli -l` (empty = daemon not running or wrong network).

**Pairing times out:**
- The `ser8` system has no firewall configured, so no port rules are needed.
- If a firewall is added later, open TCP+UDP **1714–1764** on the local interface.

**Clipboard sync not working:**
- Verify `wl-clipboard` is installed: `which wl-copy`.
- KDE Connect clipboard plugin requires the Wayland clipboard to be accessible — ensure `dbus-update-activation-environment --all` ran at session start (it does via `config.kdl`).

**Tray icon missing:**
- DankMaterialShell/Quickshell supports SNI tray icons natively.
- If the icon is absent, restart the session or run `kdeconnect-indicator &` manually.

## Notes

- **Valent** (GTK4/libadwaita rewrite of KDE Connect, no Qt deps) is not yet in Guix channels as of 2026-06. Revisit as a future replacement once packaged.
- For more resilient daemon management, `kdeconnectd` can be run as a Guix home shepherd service instead of `spawn-at-startup`.
