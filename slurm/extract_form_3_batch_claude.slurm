#!/bin/bash

#SBATCH --job-name=extract-batch-claude
#SBATCH --partition=dev
#SBATCH --output=logs/extract_claude_%j.out
#SBATCH --error=logs/extract_claude_%j.err
#SBATCH --time=00:10:00
#SBATCH --mem=1G
#SBATCH --cpus-per-task=1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=ltdarc@stanford.edu

# Extracts 100 SEC Form 3 filings (NUM_FILINGS in the script) via the Stanford AI
# API and writes one JSON per filing into results/.
#
# Sized from job 422951, which ran this same workload over 10 filings: 12s
# elapsed, 127MB peak RSS. The loop is serial and I/O-bound, so time scales
# roughly linearly (~2 min for 100) while RAM stays flat (~130MB). The 10-minute
# limit is headroom for API latency, not compute.
#
# Runs on the dev partition: fine for a ~2 min job, but dev caps you at 2 CPUs
# total, so nothing else of yours can run there at the same time.
#
# Run from the repo root so the log paths above resolve:
#     mkdir -p logs
#     sbatch slurm/extract_form_3_batch_claude.slurm

# Navigate to your project
cd $HOME/gsb-research-computing-ai-skills

# Activate your virtual environment
source .venv/bin/activate

python scripts/extract_form_3_batch.py
