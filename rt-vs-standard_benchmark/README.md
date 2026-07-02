# PREEMPT vs PREEMPT_RT Benchmark on Raspberry Pi OS (Pi 5)

A/B comparison between `kernel8.img` (standard) and `kernel8_rt.img` (PREEMPT_RT)
using cyclictest under stress-ng load, with Mann-Whitney U statistical
test and rank-biserial correlation.

## Prerequisites

```bash
sudo apt install rt-tests stress-ng
pip install scipy numpy pandas --break-system-packages
```

## Workflow

### 1. Copy the scripts to the Raspberry Pi

```bash
scp -r rt_benchmark/ <your_raspberry_ip>:~/
ssh <your_user>@<your_raspberry_ip>
cd rt_benchmark
chmod +x toggle_kernel.sh run_benchmark.sh analyze_benchmark.py
```

### 2. Run on the standard kernel

```bash
sudo ./toggle_kernel.sh standard
sudo reboot
```

After rebooting, verify you're on the right kernel:

```bash
sudo ./toggle_kernel.sh status
uname -a   # must NOT contain "PREEMPT_RT"
```

Run the benchmark (10 runs of 60s, adjust n_reps/duration according to the
time you have available — more runs = more robust statistical test):

```bash
sudo ./run_benchmark.sh standard 10 60 ~/benchmark_results
```

### 3. Run on the RT kernel

```bash
sudo ./toggle_kernel.sh rt
sudo reboot
```

```bash
sudo ./toggle_kernel.sh status
uname -a   # MUST contain "PREEMPT_RT"
```

```bash
sudo ./run_benchmark.sh rt 10 60 ~/benchmark_results
```

### 4. Statistical analysis

```bash
python3 analyze_benchmark.py ~/benchmark_results \
    --group-a standard --group-b rt \
    --csv-out ~/benchmark_results/all_samples.csv
```

This produces:
- descriptive statistics (min/mean/median/p95/p99/max) for each kernel
- Mann-Whitney U test (U statistic, p-value)
- rank-biserial correlation as effect size
- `summary_stats.csv` and (optionally) `all_samples.csv` with all
  samples expanded, ready for further analysis in R/Python or for the paper

## Methodological notes

- Each cyclictest run uses `-t -a` (one measurement thread per core, pinned)
  so each file contains samples for all 4 cores of the Pi 5.
- The stress-ng load (`--cpu 4 --io 2 --vm 2`) saturates CPU, I/O and memory
  simultaneously: this is the condition where PREEMPT_RT makes a difference
  compared to the standard kernel (at idle the two distributions tend
  to overlap, as you had already observed).
- `run_benchmark.sh` inserts a 3s load settling period before starting
  to measure, and a 5s pause between runs, to reduce autocorrelation
  between consecutive runs.
- The parser expands the cyclictest histogram (latency bucket -> count)
  into the full multiset of original samples (no loss of
  information, unlike using only the min/avg/max reported in cyclictest's
  text summary).
- `toggle_kernel.sh` saves a timestamped backup of `config.txt` on each
  change, so you can manually roll back in case of boot issues.
