#!/bin/bash
# toggle_kernel.sh - passa tra kernel standard (kernel8.img) e RT (kernel8_rt.img)
# su Raspberry Pi OS (Pi 5 / BCM2712), modificando /boot/firmware/config.txt.
#
# Uso:
#   sudo ./toggle_kernel.sh standard   # imposta il prossimo boot su kernel8.img
#   sudo ./toggle_kernel.sh rt         # imposta il prossimo boot su kernel8_rt.img
#   sudo ./toggle_kernel.sh status     # mostra kernel configurato vs kernel in esecuzione
#
# Dopo aver impostato standard/rt, serve un reboot manuale (sudo reboot) per
# far effetto: lo script non riavvia automaticamente per lasciarti il
# controllo su quando interrompere eventuali run in corso.

set -euo pipefail

CONFIG="/boot/firmware/config.txt"
KERNEL_STD="kernel8.img"
KERNEL_RT="kernel8_rt.img"

usage() {
    echo "Uso: sudo $0 [standard|rt|status]"
    exit 1
}

[ "$(id -u)" -eq 0 ] || { echo "Esegui con sudo."; exit 1; }
[ $# -eq 1 ] || usage

current_configured_kernel() {
    grep -E "^kernel=" "$CONFIG" 2>/dev/null | tail -1 | cut -d= -f2 \
        || echo "(nessuna riga kernel= esplicita, default implicito: ${KERNEL_STD})"
}

case "$1" in
    status)
        echo "Kernel configurato in config.txt : $(current_configured_kernel)"
        echo "Kernel attualmente in esecuzione  : $(uname -r)"
        echo "uname -v                          : $(uname -v)"
        ;;
    standard|rt)
        TARGET="$KERNEL_STD"
        [ "$1" = "rt" ] && TARGET="$KERNEL_RT"

        if [ ! -f "/boot/firmware/${TARGET}" ]; then
            echo "ERRORE: /boot/firmware/${TARGET} non esiste."
            echo "Verifica con: ls /boot/firmware/kernel*.img"
            exit 1
        fi

        cp "$CONFIG" "${CONFIG}.bak.$(date +%s)"
        sed -i '/^kernel=/d' "$CONFIG"
        echo "kernel=${TARGET}" >> "$CONFIG"

        echo "Impostato kernel=${TARGET} in ${CONFIG}"
        echo "Backup salvato come ${CONFIG}.bak.<timestamp>"
        echo ""
        echo "Riavvia ora con: sudo reboot"
        ;;
    *)
        usage
        ;;
esac
