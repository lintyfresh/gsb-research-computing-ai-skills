#!/bin/bash
# Approach 1 — "Ways to Parallelize": ONE JOB, MANY CORES.
# One Slurm job that reserves 2 cores; xargs -P fans the filings out across
# them *inside* the job. Parallelism within a job: your code splits the work,
# not the scheduler.
#
# Run from the repo root — that's where .env lives, and the log paths below are
# relative to wherever you submit from. Slurm won't create logs/ for you; it
# fails the job outright if the directory is missing.
#   mkdir -p logs && sbatch .instructor/parallelization_demos/2_one_job_many_cores.slurm
#SBATCH --job-name=demo-one-job-many-cores
#SBATCH --partition=normal
#SBATCH --output=logs/demo2_%j.out
#SBATCH --error=logs/demo2_%j.err
#SBATCH --time=00:10:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=2

cd $HOME/gsb-research-computing-ai-skills
source .venv/bin/activate

# Fail before spending API calls if the key isn't where load_dotenv() looks.
if ! grep -q '^STANFORD_API_KEY=' .env 2>/dev/null; then
    echo "No STANFORD_API_KEY in $PWD/.env — see docs/day2/key-vault.md" >&2
    exit 1
fi

# One results directory per run, so a rerun never inherits the last run's
# output. extract_one_url.py skips a filing whose .json already exists, which
# would otherwise make the second run look instant and spoil the comparison.
export OUT=/scratch/users/$USER/demo_results/$SLURM_JOB_ID
LIST=/scratch/users/$USER/demo_urls.txt
mkdir -p "$OUT"
python .instructor/parallelization_demos/make_url_list.py "$LIST"

# -P runs up to $SLURM_CPUS_PER_TASK extractions at once — one per reserved core.
# Each core grabs the next filing the moment it finishes one (dynamic waves).
xargs -P "$SLURM_CPUS_PER_TASK" -n1 \
    bash -c 'python .instructor/parallelization_demos/extract_one_url.py "$1" "$OUT/$(basename "$1" .txt).json"' _ < "$LIST"
