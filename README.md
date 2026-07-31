# secmon

Enable/disable a secondary monitor on GNOME/X11 with a keyboard shortcut, switching
both the X layout (`xrandr`) and the monitor's own input source over DDC/CI
(`ddcutil`) — so the display follows the laptop instead of sitting on "no signal".

Built for a laptop + ultrawide setup (eDP + HDMI, NVIDIA proprietary driver on
Pop!_OS), but the outputs and modes are plain variables at the top of the script.

---

## Requirements

| | |
|---|---|
| Session | **X11** — `xrandr` cannot control a Wayland session |
| Desktop | GNOME (uses `gsettings` custom keybindings) |
| Packages | `git`, `x11-xserver-utils` (xrandr), `ddcutil` *(optional, for input switching)* |

```bash
sudo apt install git x11-xserver-utils ddcutil
```

Check your session type — if this prints `wayland`, log out and pick "on Xorg" at
the login screen:

```bash
echo $XDG_SESSION_TYPE
```

---

## Download and run

**1. Clone the repository**

```bash
git clone git@github.com:gartisk/ddc-switch-monitor.git
cd secmon
```

**2. Edit the configuration** — set the values at the top of `secmon` to match your
hardware (see next section). Do this **before** installing: the installer copies the
file as-is.

```bash
nano secmon
```

**3. Install**

```bash
chmod +x secmon-setup.sh
./secmon-setup.sh --ddc
```

This copies `secmon` to `~/.local/bin/`, registers the <kbd>Super</kbd>+<kbd>F11</kbd>
and <kbd>Super</kbd>+<kbd>F12</kbd> shortcuts, and sets up i2c permissions so
`ddcutil` works without `sudo`. Drop `--ddc` to skip the DDC/CI part (no `sudo` needed).

**4. Log out and back in** — the `i2c` group membership only applies to a new session.
Only required if you used `--ddc`.

To update later: `git pull && ./secmon-setup.sh`.

If `~/.local/bin` isn't on your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

---

## Configuring for your monitors

The defaults almost certainly don't match your hardware. Get the real values:

```bash
xrandr --query          # output names, resolutions, refresh rates
ddcutil detect          # monitor model string
ddcutil capabilities | grep -A10 'Feature: 60'   # valid input-source codes
```

Then edit the block at the top of `secmon`:

```bash
LAPTOP_OUT="eDP-1-1"        # internal panel
LAPTOP_MODE="2560x1600"
LAPTOP_RATE="165"

EXT_OUT="HDMI-0"            # external monitor
EXT_MODE="3440x1440"
EXT_RATE="100"

DDC_MODEL="CU34G2XP"        # from `ddcutil detect`
DDC_INPUT_ON="0x11"         # input the PC is plugged into (0x11 = HDMI-1)
DDC_INPUT_OFF="0x12"        # input to hand back when disabling
```

The external monitor sits at `0x0` with the laptop to its right. To flip that, swap
the `--pos` values in `layout_dual()`.

If you've already installed, you can edit `~/.local/bin/secmon` directly instead of
reinstalling.

---

## Usage

| Command | Effect |
|---|---|
| `secmon on` | External input → PC, dual-screen layout |
| `secmon off` | Laptop only, external input released |
| `secmon toggle` | Whichever is the opposite of the current state |
| `secmon status` | `active` / `inactive` / `disconnected` |

Running `secmon` with no argument is the same as `toggle`.

### Keyboard shortcuts

- <kbd>Super</kbd>+<kbd>F11</kbd> → `secmon on`
- <kbd>Super</kbd>+<kbd>F12</kbd> → `secmon off`

They appear under **Settings → Keyboard → View and Customize Shortcuts → Custom
Shortcuts**, where you can rebind them. Existing custom shortcuts are preserved.

Prefer a single key? Change one entry's command to `secmon toggle`.

---

## Uninstall

```bash
./secmon-setup.sh --uninstall
```

Removes the binary and both shortcuts. The udev rule and i2c group are left in
place — remove them manually if you want:

```bash
sudo rm /etc/udev/rules.d/45-ddcutil-i2c.rules
sudo gpasswd -d "$USER" i2c
```

---

## Troubleshooting

**"Wayland session detected"** — you're on Wayland. Log out, click the gear icon at
the login screen, choose the Xorg session.

**`ddcutil` says "No displays found"** — the i2c module isn't loaded or you lack
permission. Run `./secmon-setup.sh --ddc`, log out and back in, then try
`ddcutil detect`. Some monitors also need DDC/CI enabled explicitly in their OSD menu.

**Screen goes black or reverts** — the mode/rate combination isn't supported. Confirm
it appears exactly as written in `xrandr --query` output.

**Output names change between reboots** — a known NVIDIA proprietary-driver quirk
(`HDMI-0` becoming `DP-1`, etc.). Detect it dynamically instead of hardcoding:

```bash
EXT_OUT=$(xrandr --query | awk '/ connected/ && $1 !~ /^eDP/ {print $1; exit}')
```

**Shortcut does nothing** — GNOME shortcuts don't run through a shell, so `secmon`
must be an absolute path in the keybinding. Verify:

```bash
gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/secmon-enable/" command
```

**"error: '.../secmon' not found"** — you're running the installer from outside the
repository directory. `cd` into the cloned folder first.
