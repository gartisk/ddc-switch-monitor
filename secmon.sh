#!/usr/bin/env bash
#############################################
# secmon — Enable/Disable Secondary Monitor #
#############################################
# Usage: secmon on | off | toggle | status
#
# Get your configuration values from:  xrandr --query  and  ddcutil detect

set -euo pipefail

# --- monitors ----------------------------------------------------------
LAPTOP_OUT="eDP-1-1"
LAPTOP_MODE="2560x1600"
LAPTOP_RATE="165"

EXT_OUT="HDMI-0"
EXT_MODE="3440x1440"
EXT_RATE="100"

# --- DDC/CI (AOC CU34G2XP, VCP 0x60 = input source) --------------------
# Identify by model rather than "--display 1": the display number shifts
# depending on detection order at boot.
DDC_MODEL="CU34G2XP"
DDC_INPUT_ON="0x11"    # HDMI-1  (this PC)
DDC_INPUT_OFF="0x12"   # HDMI-2  (other source)
DDC_WAKE_DELAY="1.5"   # seconds to let the monitor wake after input switch

# -----------------------------------------------------------------------
die() { echo "secmon: $*" >&2; exit 1; }
log() { echo "secmon: $*"; }

EXT_WIDTH="${EXT_MODE%x*}"

check_env() {
    [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && \
        die "Wayland session detected: xrandr cannot control it. Log in under X11."
    command -v xrandr >/dev/null || die "xrandr not found."
}

ddc() {
    command -v ddcutil >/dev/null || { log "ddcutil missing, skipping input switch."; return 0; }
    # Do not abort on DDC failure: xrandr should still run.
    ddcutil --model "$DDC_MODEL" setvcp 60 "$1" 2>/dev/null \
        || log "warning: failed to switch input over DDC/CI."
}

ext_connected() {
    xrandr --query | grep -q "^${EXT_OUT} connected"
}

ext_active() {
    # An active output shows its geometry (e.g. 3440x1440+0+0) on its line.
    xrandr --query | awk -v o="$EXT_OUT" \
        '$1==o && $0 ~ /[0-9]+x[0-9]+\+[0-9]+\+[0-9]+/ {found=1} END{exit !found}'
}

layout_dual() {
    xrandr \
        --output "$EXT_OUT"    --mode "$EXT_MODE"    --rate "$EXT_RATE"    --pos 0x0 \
        --output "$LAPTOP_OUT" --mode "$LAPTOP_MODE" --rate "$LAPTOP_RATE" --pos "${EXT_WIDTH}x0" --primary
}

layout_single() {
    xrandr \
        --output "$LAPTOP_OUT" --mode "$LAPTOP_MODE" --rate "$LAPTOP_RATE" --pos 0x0 --primary \
        --output "$EXT_OUT"    --off
}

cmd_on() {
    ext_connected || die "'$EXT_OUT' is not connected."
    ddc "$DDC_INPUT_ON"
    sleep "$DDC_WAKE_DELAY"          # give the monitor time to sync
    layout_dual
    log "secondary monitor enabled."
}

cmd_off() {
    layout_single                    # turn the output off first...
    ddc "$DDC_INPUT_OFF"             # ...then release the input
    log "secondary monitor disabled."
}

cmd_toggle() {
    if ext_active; then cmd_off; else cmd_on; fi
}

cmd_status() {
    ext_connected || { echo "disconnected"; return; }
    ext_active && echo "active" || echo "inactive"
}

check_env
case "${1:-toggle}" in
    on)     cmd_on ;;
    off)    cmd_off ;;
    toggle) cmd_toggle ;;
    status) cmd_status ;;
    *)      die "usage: $(basename "$0") {on|off|toggle|status}" ;;
esac
