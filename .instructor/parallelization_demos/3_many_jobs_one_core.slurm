#!/bin/bash
# Approach 2 — "Ways to Parallelize": MANY JOBS, ONE CORE EACH.
# A job array: the scheduler launches one independent job per array task
# (possibly on different nodes), and each task works its own slice of the
# filings serially on a single core. Parallelism across jobs: Slurm splits
# the work by task ID.
#
# Run from the repo root — that's where .env lives, and the log paths below are
# relative to wherever you submit from. Slurm won't create logs/ for you; it
# fails the job outright if the directory is missing.
#   mkdir -p logs && sbatch .instructor/parallelization_demos/3_many_jobs_one_core.slurm
#SBATCH --job-name=demo-many-jobs-one-core
#SBATCH --partition=normal
#SBATCH --output=logs/demo3_%A_%a.out
#SBATCH --error=logs/demo3_%A_%a.err
#SBATCH --time=00:10:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH --array=1-2

cd $HOME/gsb-research-computing-ai-skills
source .venv/bin/activate

# Fail before spending API calls if the key isn't where load_dotenv() looks.
if ! grep -q '^STANFORD_API_KEY=' .env 2>/dev/null; then
    echo "No STANFORD_API_KEY in $PWD/.env — see docs/day2/key-vault.md" >&2
    exit 1
fi

# One results directory per run, so a rerun never inherits the last run's
# output (extract_one_url.py skips a filing whose .json already exists).
# SLURM_ARRAY_JOB_ID is the same for every task of this array, so all tasks
# share one directory — they write disjoint filings into it, never the same file.
OUT=/scratch/users/$USER/demo_results/${SLURM_ARRAY_JOB_ID:-$SLURM_JOB_ID}
LIST=/scratch/users/$USER/demo_urls.txt
mkdir -p "$OUT"
python .instructor/parallelization_demos/make_url_list.py "$LIST"   # every task rebuilds the same list; harmless

# split the list into as many contiguous chunks as there are array tasks;
# this task processes chunk number $SLURM_ARRAY_TASK_ID, one filing at a time
TOTAL=$(wc -l < "$LIST")
CHUNK=$(( (TOTAL + SLURM_ARRAY_TASK_COUNT - 1) / SLURM_ARRAY_TASK_COUNT ))
START=$(( (SLURM_ARRAY_TASK_ID - 1) * CHUNK + 1 ))
END=$(( START + CHUNK - 1 ))

sed -n "${START},${END}p" "$LIST" | while read -r url; do
    python .instructor/parallelization_demos/extract_one_url.py "$url" "$OUT/$(basename "$url" .txt).json"
done
