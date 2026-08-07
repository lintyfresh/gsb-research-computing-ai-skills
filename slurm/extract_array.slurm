#!/bin/bash

#SBATCH --job-name=extract-array
#SBATCH --partition=normal
#SBATCH --output=logs/extract_array_%A_%a.out
#SBATCH --error=logs/extract_array_%A_%a.err
#SBATCH --time=00:10:00
#SBATCH --mem=1G
#SBATCH --cpus-per-task=1
#SBATCH --array=1-100
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=ltdarc@stanford.edu

# Approach 2 from docs/day4/parallelization.md -- MANY JOBS, ONE CORE EACH.
# One array task per filing: task N extracts filing N from data/aws_links.csv.
# The array is what replaces the Day 3 for loop.
#
# --partition=normal, NOT dev: the dev QoS caps a user at 2 CPUs, which would
# quietly serialize this array two tasks at a time and defeat the point.
#
# Sized from job 424588: ~3.25s per filing plus a few seconds of Python imports,
# so 10 minutes is generous headroom for one filing, not a real estimate.
#
# %A is the array's job ID and %a the task index, so all 100 tasks get their own
# log instead of overwriting one file. Slurm resolves these paths relative to the
# directory you submit from, and won't create logs/ for you.
#
# Run from the repo root:
#     mkdir -p logs
#     sbatch slurm/extract_array.slurm

cd $HOME/gsb-research-computing-ai-skills
source .venv/bin/activate

# Fail before spending API calls if the key isn't where load_dotenv() looks.
# With 100 tasks a missing key means 100 identical failures, so check once.
if ! grep -q '^STANFORD_API_KEY=' .env 2>/dev/null; then
    echo "No STANFORD_API_KEY in $PWD/.env — see docs/day2/key-vault.md" >&2
    exit 1
fi

python scripts/extract_array.py "$SLURM_ARRAY_TASK_ID"
