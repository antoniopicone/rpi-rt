#!/bin/bash
# run_benchmark.sh - runs N repeated cyclictest runs under stress-ng load
# and saves the raw output (histogram included) of each to a separate file.
#
# Usage:
#   sudo ./run_benchmark.sh <label> <n_reps> <duration_sec> <output_dir>
#
# Example (after rebooting on the RT kernel):
#   sudo ./run_benchmark.sh rt 10 60 ~/benchmark_results
#
# Example (after rebooting on the standard kernel):
#   sudo ./run_benchmark.sh standard 10 60 ~/benchmark_results
#
# <label> ends up in the output file names and is the "kernel" column used
# later by analyze_benchmark.py for the statistical comparison.

set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo."; exit 1; }
[ $# -eq 4 ] || { echo "Usage: sudo $0 <label> <n_reps> <duration_sec> <output_dir>"; exit 1; }

LABEL="$1"
NREPS="$2"
DURATION="$3"
OUTDIR="$4"

mkdir -p "$OUTDIR"

command -v cyclictest >/dev/null 2>&1 || { echo "cyclictest not found: sudo apt install rt-tests"; exit 1; }
command -v stress-ng  >/dev/null 2>&1 || { echo "stress-ng not found: sudo apt install stress-ng"; exit 1; }

echo "=== cyclictest benchmark ==="
echo "Running kernel        : $(uname -r)"
echo "uname -v              : $(uname -v)"
echo "Label                 : $LABEL"
echo "Repetitions           : $NREPS"
echo "Duration per run      : ${DURATION}s"
echo "Output dir            : $OUTDIR"
echo "============================"

# save a manifest with the kernel metadata for each run (useful during
# analysis to verify that two runs on the same kernel weren't compared
# by mistake)
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

    sleep 3   # let the load settle before starting to measure

    OUTFILE="${OUTDIR}/cyclictest_${LABEL}_rep${i}.txt"
    cyclictest -t -a -p 90 -m -D "$DURATION" --histogram=1000 -q > "$OUTFILE"

    wait "$STRESS_PID" 2>/dev/null || true

    echo "Saved: $OUTFILE"
    sleep 5   # pause between runs so conditions aren't inherited from the previous run
done

echo ""
echo "Done. ${NREPS} cyclictest_${LABEL}_rep*.txt files in ${OUTDIR}"
echo "Next step: sudo ./toggle_kernel.sh <other-kernel> && sudo reboot,"
echo "then repeat with the other label, and finally run analyze_benchmark.py"
