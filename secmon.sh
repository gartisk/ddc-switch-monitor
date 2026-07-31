#!/usr/bin/env bash
##########################################################
# secmon-setup — install the script and register shortcuts
#
#   ./secmon-setup.sh            -> install + shortcuts
#   ./secmon-setup.sh --ddc      -> + i2c permissions
#   ./secmon-setup.sh --uninstall
##########################################################
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/secmon"

# Local install: 'secmon' must sit next to this script (as it does after
# a git clone).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/secmon"

KB=org.gnome.settings-daemon.plugins.media-keys
BASE=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
EN="$BASE/secmon-enable/"
DIS="$BASE/secmon-disable/"

# --- shortcut list: append without destroying existing entries ---------
kb_list_add() {
    local cur; cur=$(gsettings get "$KB" custom-keybindings)
    [[ "$cur" == "@as []" ]] && cur="[]"
    local p
    for p in "$@"; do
        [[ "$cur" == *"'$p'"* ]] && continue
        if [[ "$cur" == "[]" ]]; then cur="['$p']"
        else cur="${cur%]}, '$p']"; fi
    done
    gsettings set "$KB" custom-keybindings "$cur"
}

kb_list_del() {
    local cur; cur=$(gsettings get "$KB" custom-keybindings)
    [[ "$cur" == "@as []" ]] && return 0
    local p
    for p in "$@"; do
        cur="${cur//\'$p\', /}"; cur="${cur//, \'$p\'/}"; cur="${cur//\'$p\'/}"
    done
    [[ "$cur" == "[]" || "$cur" == "[ ]" ]] && cur="@as []"
    gsettings set "$KB" custom-keybindings "$cur"
}

install_bin() {
    [[ -f "$SRC" ]] || {
        echo "error: '$SRC' not found." >&2
        echo "Run this script from the cloned repository directory." >&2
        exit 1
    }
    mkdir -p "$BIN_DIR"
    install -m 755 "$SRC" "$BIN"
    echo "installed: $BIN"
    case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "warning: $BIN_DIR is not on your PATH";; esac
}

install_keys() {
    kb_list_add "$EN" "$DIS"
    gsettings set "$KB.custom-keybinding:$EN"  name    'Secondary Monitor Enable'
    gsettings set "$KB.custom-keybinding:$EN"  command "$BIN on"
    gsettings set "$KB.custom-keybinding:$EN"  binding '<Super>F11'
    gsettings set "$KB.custom-keybinding:$DIS" name    'Secondary Monitor Disable'
    gsettings set "$KB.custom-keybinding:$DIS" command "$BIN off"
    gsettings set "$KB.custom-keybinding:$DIS" binding '<Super>F12'
    echo "shortcuts registered: <Super>F11 / <Super>F12"
}

setup_ddc() {
    getent group i2c >/dev/null || sudo groupadd i2c
    echo 'KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"' \
        | sudo tee /etc/udev/rules.d/45-ddcutil-i2c.rules >/dev/null
    id -nG "$USER" | grep -qw i2c || sudo usermod -aG i2c "$USER"
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    grep -qxF i2c-dev /etc/modules-load.d/i2c-dev.conf 2>/dev/null \
        || echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
    sudo modprobe i2c-dev
    echo "i2c configured. Log out and back in for the group change to apply."
}

uninstall() {
    kb_list_del "$EN" "$DIS"
    dconf reset -f "$EN"  2>/dev/null || true
    dconf reset -f "$DIS" 2>/dev/null || true
    rm -f "$BIN"
    echo "uninstalled."
}

case "${1:-}" in
    --uninstall) uninstall ;;
    --ddc)       install_bin; install_keys; setup_ddc ;;
    "")          install_bin; install_keys ;;
    *)           echo "usage: $0 [--ddc|--uninstall]" >&2; exit 1 ;;
esac
