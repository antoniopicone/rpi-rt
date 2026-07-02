#!/usr/bin/env python3
"""
analyze_benchmark.py - confronta le distribuzioni di latenza cyclictest tra
due kernel (es. standard vs RT) con test di Mann-Whitney U e rank-biserial
correlation, seguendo la stessa metodologia statistica usata nel benchmark
DPSim (PREEMPT vs PREEMPT_RT su Raspberry Pi 5, Mann-Whitney U + rank-biserial).

Uso:
    python3 analyze_benchmark.py <output_dir> [--group-a standard] [--group-b rt]

<output_dir> deve contenere i file generati da run_benchmark.sh:
    cyclictest_<label>_rep<N>.txt

Richiede: pip install scipy numpy pandas --break-system-packages
"""

import argparse
import glob
import os
import re
import sys

import numpy as np
import pandas as pd
from scipy import stats

HIST_LINE_RE = re.compile(r"^(\d{6})((?:\s+\d+)+)\s*$")


def parse_cyclictest_file(path):
    """Estrae tutti i campioni di latenza (in microsecondi) da un file di
    output cyclictest con istogramma. Ritorna un array numpy di interi,
    uno per campione, ottenuto espandendo i bucket (latenza, conteggio)
    per tutti i thread presenti nel file."""
    samples = []
    with open(path, "r", errors="replace") as f:
        for line in f:
            m = HIST_LINE_RE.match(line.strip())
            if not m:
                continue
            latency_us = int(m.group(1))
            counts = [int(x) for x in m.group(2).split()]
            for c in counts:
                if c > 0:
                    samples.append(np.full(c, latency_us, dtype=np.int32))
    if not samples:
        return np.array([], dtype=np.int32)
    return np.concatenate(samples)


def load_group(output_dir, label):
    pattern = os.path.join(output_dir, f"cyclictest_{label}_rep*.txt")
    files = sorted(glob.glob(pattern))
    if not files:
        sys.exit(f"Nessun file trovato per label '{label}' con pattern: {pattern}")

    rows = []
    for fpath in files:
        rep = os.path.basename(fpath)
        samples = parse_cyclictest_file(fpath)
        if samples.size == 0:
            print(f"ATTENZIONE: nessun campione estratto da {fpath}", file=sys.stderr)
            continue
        for v in samples:
            rows.append((label, rep, int(v)))
    df = pd.DataFrame(rows, columns=["kernel", "run_file", "latency_us"])
    return df


def rank_biserial_from_u(u_stat, n1, n2):
    """Rank-biserial correlation a partire dalla statistica U di Mann-Whitney.
    r = 1 - 2U / (n1*n2). Convenzione: U qui riferito al gruppo 1."""
    return 1 - (2 * u_stat) / (n1 * n2)


def describe(series):
    return {
        "n": len(series),
        "min": series.min(),
        "mean": series.mean(),
        "median": series.median(),
        "p95": series.quantile(0.95),
        "p99": series.quantile(0.99),
        "max": series.max(),
        "std": series.std(),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("output_dir", help="Directory con i file cyclictest_<label>_rep*.txt")
    ap.add_argument("--group-a", default="standard", help="Label primo gruppo (default: standard)")
    ap.add_argument("--group-b", default="rt", help="Label secondo gruppo (default: rt)")
    ap.add_argument("--csv-out", default=None, help="Percorso CSV campioni espansi (opzionale)")
    args = ap.parse_args()

    print(f"Caricamento gruppo '{args.group_a}'...")
    df_a = load_group(args.output_dir, args.group_a)
    print(f"  -> {len(df_a)} campioni da {df_a['run_file'].nunique()} run")

    print(f"Caricamento gruppo '{args.group_b}'...")
    df_b = load_group(args.output_dir, args.group_b)
    print(f"  -> {len(df_b)} campioni da {df_b['run_file'].nunique()} run")

    df_all = pd.concat([df_a, df_b], ignore_index=True)

    if args.csv_out:
        df_all.to_csv(args.csv_out, index=False)
        print(f"\nCampioni espansi salvati in: {args.csv_out}")

    print("\n=== Statistiche descrittive (microsecondi) ===")
    desc_a = describe(df_a["latency_us"])
    desc_b = describe(df_b["latency_us"])
    summary = pd.DataFrame([desc_a, desc_b], index=[args.group_a, args.group_b])
    print(summary.round(3).to_string())

    print("\n=== Test di Mann-Whitney U ===")
    a = df_a["latency_us"].to_numpy()
    b = df_b["latency_us"].to_numpy()

    u_stat, p_value = stats.mannwhitneyu(a, b, alternative="two-sided")
    r_rb = rank_biserial_from_u(u_stat, len(a), len(b))

    print(f"U statistic          : {u_stat:.1f}")
    print(f"p-value (two-sided)  : {p_value:.6g}")
    print(f"rank-biserial r      : {r_rb:.4f}")

    if abs(r_rb) < 0.1:
        effect = "trascurabile"
    elif abs(r_rb) < 0.3:
        effect = "piccolo"
    elif abs(r_rb) < 0.5:
        effect = "medio"
    else:
        effect = "grande"
    print(f"dimensione effetto   : {effect}")

    direction = args.group_a if r_rb > 0 else args.group_b
    print(f"\nInterpretazione: {direction} tende ad avere latenze più basse "
          f"(r={r_rb:+.4f}). {'Differenza NON significativa (p>0.05).' if p_value > 0.05 else 'Differenza statisticamente significativa (p<0.05).'}")

    out_summary_path = os.path.join(args.output_dir, "summary_stats.csv")
    summary.to_csv(out_summary_path)
    print(f"\nRiepilogo statistiche salvato in: {out_summary_path}")


if __name__ == "__main__":
    main()
