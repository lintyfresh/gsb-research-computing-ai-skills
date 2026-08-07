#!/bin/bash
# Baseline — "Ways to Parallelize": ONE JOB, ONE CORE.
# The serial baseline from Day 3: one Slurm job, one core, a for loop.
# The loop can't start filing 2 until filing 1 is done.
#
# Run from the repo root — that's where .env lives, and the log paths below are
# relative to wherever you submit from. Slurm won't create logs/ for you; it
# fails the job outright if the directory is missing.
#   mkdir -p logs && sbatch .instructor/parallelization_demos/1_one_job_one_core.slurm
#SBATCH --job-name=demo-one-job-one-core
#SBATCH --partition=normal
#SBATCH --output=logs/demo1_%j.out
#SBATCH --error=logs/demo1_%j.err
#SBATCH --time=00:10:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1

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
OUT=/scratch/users/$USER/demo_results/$SLURM_JOB_ID
LIST=/scratch/users/$USER/demo_urls.txt
mkdir -p "$OUT"
python .instructor/parallelization_demos/make_url_list.py "$LIST"

# one core walks the filings in sequence
while read -r url; do
    python .instructor/parallelization_demos/extract_one_url.py "$url" "$OUT/$(basename "$url" .txt).json"
done < "$LIST"
