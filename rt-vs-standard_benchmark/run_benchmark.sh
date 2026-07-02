#!/bin/bash
# run_benchmark.sh - esegue N run ripetute di cyclictest sotto carico stress-ng
# e salva l'output grezzo (istogramma incluso) di ognuna in un file separato.
#
# Uso:
#   sudo ./run_benchmark.sh <label> <n_reps> <durata_sec> <output_dir>
#
# Esempio (dopo aver riavviato sul kernel RT):
#   sudo ./run_benchmark.sh rt 10 60 ~/benchmark_results
#
# Esempio (dopo aver riavviato sul kernel standard):
#   sudo ./run_benchmark.sh standard 10 60 ~/benchmark_results
#
# <label> finisce nel nome dei file di output ed è la colonna "kernel" usata
# poi da analyze_benchmark.py per il confronto statistico.

set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Esegui con sudo."; exit 1; }
[ $# -eq 4 ] || { echo "Uso: sudo $0 <label> <n_reps> <durata_sec> <output_dir>"; exit 1; }

LABEL="$1"
NREPS="$2"
DURATION="$3"
OUTDIR="$4"

mkdir -p "$OUTDIR"

command -v cyclictest >/dev/null 2>&1 || { echo "cyclictest non trovato: sudo apt install rt-tests"; exit 1; }
command -v stress-ng  >/dev/null 2>&1 || { echo "stress-ng non trovato: sudo apt install stress-ng"; exit 1; }

echo "=== Benchmark cyclictest ==="
echo "Kernel in esecuzione : $(uname -r)"
echo "uname -v             : $(uname -v)"
echo "Label                : $LABEL"
echo "Ripetizioni           : $NREPS"
echo "Durata per run        : ${DURATION}s"
echo "Output dir             : $OUTDIR"
echo "============================"

# salva un manifest con i metadati del kernel per ogni run (utile in fase di
# analisi per verificare di non aver confrontato per errore due run sullo
# stesso kernel)
MANIFEST="${OUTDIR}/manifest_${LABEL}.txt"
{
    echo "label=${LABEL}"
    echo "kernel_release=$(uname -r)"
    echo "kernel_version=$(uname -v)"
    echo "timestamp=$(date -Iseconds)"
    echo "n_reps=${NREPS}"
    echo "duration_s=${DURATION}"
} > "$MANIFEST"

for i in $(seq 1 "$NREPS"); do
    echo ""
    echo "--- Run ${i}/${NREPS} (${LABEL}) ---"

    STRESS_DUR=$((DURATION + 10))
    stress-ng --cpu 4 --io 2 --vm 2 --vm-bytes 128M --timeout "${STRESS_DUR}s" \
        > "${OUTDIR}/stress_${LABEL}_rep${i}.log" 2>&1 &
    STRESS_PID=$!

    sleep 3   # lascia stabilizzare il carico prima di iniziare a misurare

    OUTFILE="${OUTDIR}/cyclictest_${LABEL}_rep${i}.txt"
    cyclictest -t -a -p 90 -m -D "$DURATION" --histogram=1000 -q > "$OUTFILE"

    wait "$STRESS_PID" 2>/dev/null || true

    echo "Salvato: $OUTFILE"
    sleep 5   # pausa tra le run per non far ereditare condizioni dalla run precedente
done

echo ""
echo "Completato. ${NREPS} file cyclictest_${LABEL}_rep*.txt in ${OUTDIR}"
echo "Prossimo passo: sudo ./toggle_kernel.sh <altro-kernel> && sudo reboot,"
echo "poi ripeti con l'altra label, infine lancia analyze_benchmark.py"
