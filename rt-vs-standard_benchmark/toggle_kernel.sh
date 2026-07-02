#!/bin/bash
# toggle_kernel.sh - switches between the standard kernel (kernel8.img) and
# RT (kernel8_rt.img) on Raspberry Pi OS (Pi 5 / BCM2712), by modifying
# /boot/firmware/config.txt.
#
# Usage:
#   sudo ./toggle_kernel.sh standard   # set kernel8.img for the next boot
#   sudo ./toggle_kernel.sh rt         # set kernel8_rt.img for the next boot
#   sudo ./toggle_kernel.sh status     # show configured kernel vs running kernel
#
# After setting standard/rt, a manual reboot (sudo reboot) is required to
# take effect: the script doesn't reboot automatically so you keep
# control over when to interrupt any runs in progress.

set -euo pipefail

CONFIG="/boot/firmware/config.txt"
KERNEL_STD="kernel8.img"
KERNEL_RT="kernel8_rt.img"

usage() {
    echo "Usage: sudo $0 [standard|rt|status]"
    exit 1
}

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo."; exit 1; }
[ $# -eq 1 ] || usage

current_configured_kernel() {
    grep -E "^kernel=" "$CONFIG" 2>/dev/null | tail -1 | cut -d= -f2 \
        || echo "(no explicit kernel= line, implicit default: ${KERNEL_STD})"
}

case "$1" in
    status)
        echo "Kernel configured in config.txt : $(current_configured_kernel)"
        echo "Kernel currently running        : $(uname -r)"
        echo "uname -v                        : $(uname -v)"
        ;;
    standard|rt)
        TARGET="$KERNEL_STD"
        [ "$1" = "rt" ] && TARGET="$KERNEL_RT"

        if [ ! -f "/boot/firmware/${TARGET}" ]; then
            echo "ERROR: /boot/firmware/${TARGET} does not exist."
            echo "Check with: ls /boot/firmware/kernel*.img"
            exit 1
        fi

        cp "$CONFIG" "${CONFIG}.bak.$(date +%s)"
        sed -i '/^kernel=/d' "$CONFIG"
        echo "kernel=${TARGET}" >> "$CONFIG"

        echo "Set kernel=${TARGET} in ${CONFIG}"
        echo "Backup saved as ${CONFIG}.bak.<timestamp>"
        echo ""
        echo "Reboot now with: sudo reboot"
        ;;
    *)
        usage
        ;;
esac
