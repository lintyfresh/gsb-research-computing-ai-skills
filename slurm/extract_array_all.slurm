#!/bin/bash

#SBATCH --job-name=extract-array-all
#SBATCH --partition=normal
#SBATCH --output=logs/extract_array_all_%A_%a.out
#SBATCH --error=logs/extract_array_all_%A_%a.err
#SBATCH --time=00:15:00
#SBATCH --mem=1G
#SBATCH --cpus-per-task=1
#SBATCH --array=1-496
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=ltdarc@stanford.edu

# Day 4 Challenge -- all 992 filings from data/aws_links.csv.
#
# The Yens cap an array at 512 tasks (scontrol show config | grep MaxArraySize),
# so one filing per task isn't available at this size. 2 filings per task gives
# 992 / 2 = 496 tasks, which fits with room to spare.
#
# --partition=normal, NOT dev: the dev QoS caps a user at 2 CPUs.
#
# No %N concurrency cap here by choice, so your QoS limit of 100 concurrent jobs
# applies instead. Sized from job 424743: ~16s of Python startup plus ~3s per
# filing, so 15 minutes is generous headroom for a 2-filing task.
#
# %A is the array job ID and %a the task index, so all 496 tasks get their own
# log. Slurm resolves these paths relative to the directory you submit FROM, and
# won't create logs/ for you -- submit from the repo root, not from slurm/.
#
#     mkdir -p logs
#     sbatch slurm/extract_array_all.slurm

cd $HOME/gsb-research-computing-ai-skills
source .venv/bin/activate

# Fail before spending API calls if the key isn't where load_dotenv() looks.
# With 496 tasks a missing key means 496 identical failures, so check once.
if ! grep -q '^STANFORD_API_KEY=' .env 2>/dev/null; then
    echo "No STANFORD_API_KEY in $PWD/.env — see docs/day2/key-vault.md" >&2
    exit 1
fi

python scripts/extract_array_all.py "$SLURM_ARRAY_TASK_ID"
