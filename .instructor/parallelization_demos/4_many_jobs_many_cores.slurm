#!/bin/bash
# Approach 3 — "Ways to Parallelize": MANY JOBS, MANY CORES.
# Both at once: a job array (parallel across jobs) where each task also
# reserves 2 cores and fans its slice out across them with xargs -P
# (parallel within each job).
#
# Run from the repo root — that's where .env lives, and the log paths below are
# relative to wherever you submit from. Slurm won't create logs/ for you; it
# fails the job outright if the directory is missing.
#   mkdir -p logs && sbatch .instructor/parallelization_demos/4_many_jobs_many_cores.slurm
#SBATCH --job-name=demo-many-jobs-many-cores
#SBATCH --partition=normal
#SBATCH --output=logs/demo4_%A_%a.out
#SBATCH --error=logs/demo4_%A_%a.err
#SBATCH --time=00:10:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=2
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
export OUT=/scratch/users/$USER/demo_results/${SLURM_ARRAY_JOB_ID:-$SLURM_JOB_ID}
LIST=/scratch/users/$USER/demo_urls.txt
mkdir -p "$OUT"
python .instructor/parallelization_demos/make_url_list.py "$LIST"   # every task rebuilds the same list; harmless

# same chunking as demo 3: one contiguous slice of the list per array task
TOTAL=$(wc -l < "$LIST")
CHUNK=$(( (TOTAL + SLURM_ARRAY_TASK_COUNT - 1) / SLURM_ARRAY_TASK_COUNT ))
START=$(( (SLURM_ARRAY_TASK_ID - 1) * CHUNK + 1 ))
END=$(( START + CHUNK - 1 ))

# ...but within the slice, fan out across this task's reserved cores
sed -n "${START},${END}p" "$LIST" | xargs -P "$SLURM_CPUS_PER_TASK" -n1 \
    bash -c 'python .instructor/parallelization_demos/extract_one_url.py "$1" "$OUT/$(basename "$1" .txt).json"' _
