# Benchmark PREEMPT vs PREEMPT_RT su Raspberry Pi OS (Pi 5)

Confronto A/B tra `kernel8.img` (standard) e `kernel8_rt.img` (PREEMPT_RT)
tramite cyclictest sotto carico stress-ng, con test statistico di
Mann-Whitney U e rank-biserial correlation.

## Prerequisiti

```bash
sudo apt install rt-tests stress-ng
pip install scipy numpy pandas --break-system-packages
```

## Workflow

### 1. Copia gli script sul Raspberry Pi

```bash
scp -r rt_benchmark/ turing:~/
ssh turing
cd rt_benchmark
chmod +x toggle_kernel.sh run_benchmark.sh analyze_benchmark.py
```

### 2. Run sul kernel standard

```bash
sudo ./toggle_kernel.sh standard
sudo reboot
```

Dopo il riavvio, verifica di essere sul kernel giusto:

```bash
sudo ./toggle_kernel.sh status
uname -a   # NON deve contenere "PREEMPT_RT"
```

Lancia il benchmark (10 run da 60s, adatta n_reps/durata secondo il tempo
che hai a disposizione — più run = test statistico più robusto):

```bash
sudo ./run_benchmark.sh standard 10 60 ~/benchmark_results
```

### 3. Run sul kernel RT

```bash
sudo ./toggle_kernel.sh rt
sudo reboot
```

```bash
sudo ./toggle_kernel.sh status
uname -a   # DEVE contenere "PREEMPT_RT"
```

```bash
sudo ./run_benchmark.sh rt 10 60 ~/benchmark_results
```

### 4. Analisi statistica

```bash
python3 analyze_benchmark.py ~/benchmark_results \
    --group-a standard --group-b rt \
    --csv-out ~/benchmark_results/all_samples.csv
```

Questo produce:
- statistiche descrittive (min/media/mediana/p95/p99/max) per ciascun kernel
- test di Mann-Whitney U (statistica U, p-value)
- rank-biserial correlation come effect size
- `summary_stats.csv` e (opzionale) `all_samples.csv` con tutti i campioni
  espansi, pronti per ulteriori analisi in R/Python o per il paper

## Note metodologiche

- Ogni run di cyclictest usa `-t -a` (un thread di misura per core, pinnato)
  quindi ogni file contiene campioni per tutti e 4 i core del Pi 5.
- Il carico stress-ng (`--cpu 4 --io 2 --vm 2`) satura CPU, I/O e memoria
  simultaneamente: è la condizione in cui PREEMPT_RT fa la differenza
  rispetto al kernel standard (a sistema idle le due distribuzioni tendono
  a sovrapporsi, come avevi già osservato).
- `run_benchmark.sh` inserisce 3s di assestamento del carico prima di
  iniziare a misurare e 5s di pausa tra le run, per ridurre l'autocorrelazione
  tra run consecutive.
- Il parser espande l'istogramma cyclictest (bucket latenza -> conteggio)
  nell'intero multiset di campioni originali (nessuna perdita di
  informazione, a differenza dell'uso dei soli min/avg/max riportati nel
  sommario testuale di cyclictest).
- `toggle_kernel.sh` salva un backup timestampato di `config.txt` ad ogni
  modifica, per poter tornare indietro manualmente in caso di problemi di
  boot.
