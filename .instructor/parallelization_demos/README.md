# Parallelization demos (instructor)

Four Slurm scripts mapping 1:1 to the diagrams in the Day 4
["Ways to Parallelize"](../../docs/day4/parallelization.md) section.
Each extracts SEC filings from `data/aws_links.csv` — the same source as the
Day 3 batch job — varying only *how* the work is spread.

| Script | On the page | Jobs | Cores/job | Parallelism |
|---|---|---|---|---|
| `1_one_job_one_core.slurm` | the baseline | 1 | 1 | none — serial `for` loop |
| `2_one_job_many_cores.slurm` | Approach 1 | 1 | 2 | within the job (`xargs -P` across reserved cores) |
| `3_many_jobs_one_core.slurm` | Approach 2 | 2 (array) | 1 | across jobs (each task works its slice serially) |
| `4_many_jobs_many_cores.slurm` | Approach 3 | 2 (array) | 2 | both at once |

The scripts illustrate the *shape* of each approach; the filing count is a
knob, not a fixed part of the demo.

Two smaller scripts sit alongside them, for the
["Slurm Job Arrays"](../../docs/day4/slurm-arrays.md) page rather than this one.
They do no real work — the only thing on show is the shape of a submission, and
the single directive that turns one job into four:

| Script | On the page |
|---|---|
| `hello.slurm` | the first `.demo` callout — one script, one task |
| `hello_array.slurm` | the second — the same script plus `#SBATCH --array=1-4` |

```bash
mkdir -p logs
sbatch .instructor/parallelization_demos/hello.slurm
sbatch .instructor/parallelization_demos/hello_array.slurm
cat logs/hello_<arrayid>_*.out       # one file per task, via %A_%a
```

Two helpers sit alongside them too, both following the conventions of
`scripts/extract_form_3_batch.py`:

| Helper | Role |
|---|---|
| `make_url_list.py` | Pulls the first N `.txt` URLs out of `data/aws_links.csv` into a list file, one per line |
| `extract_one_url.py` | Fetches **one** filing by URL and extracts it — same schema, prompt, and model as the batch script, but one filing per invocation, which is what lets the work fan out |

`extract_one_url.py` skips a filing whose output already exists, so a rerun after
a partial failure only pays for what actually failed.

## Running

From the repo root on the Yens (a `.env` holding `STANFORD_API_KEY` must be
present there — each demo checks for it and exits before spending any API calls
if it's missing — and `logs/` must exist, since Slurm won't create it):

```bash
mkdir -p logs
sbatch .instructor/parallelization_demos/1_one_job_one_core.slurm
```

All four demos process the same **20 filings**, so their timings are directly
comparable — set once as `NUM_FILINGS` in `make_url_list.py`. That is 20 paid API
calls per demo, so budget 80 for a full four-way comparison.

All four submit to **`normal`**, and it has to be `normal` rather than `dev`.
`dev` is the natural first thought — short jobs, fast turnaround, and Day 3
introduces it as a side quest (`docs/day3/slurm-job.md:520`) — but it caps a user
at **2 CPUs**, per RCpedia's [partition
limits](https://rcpedia.stanford.edu/_user_guide/slurm/#current-partitions-and-their-limits):

| Partition | CPU limit per user | Memory | Time limit (default) |
|---|---|---|---|
| `normal` | 512 | 3000 GB | 2 days (2 h) |
| `dev` | **2** | 46 GB | 2 h (1 h) |

Against that cap, demo 4 needs 4 CPUs at once (2 jobs × 2 cores) and simply
cannot run in parallel: Slurm would run its two jobs one after the other, so the
demo built to show the *most* parallelism would post the *worst* wall-clock. It
would not error — it would just quietly invert the lesson. Demo 3 needs exactly
2 and would fit with no headroom, so anything else of yours on `dev` tips it
over too.

Time and memory were never the constraint: 10 minutes against a 2-hour ceiling,
4 GB against 46.

Expect well under a minute for the serial baseline (Day 3 measured ~2.25s per
filing), and less for the rest.

Results land in `/scratch/users/$USER/demo_results/<job-id>/` — one directory
per run, named for the job ID (for the array demos, the shared
`SLURM_ARRAY_JOB_ID`, so a whole array writes into one directory). Every run
therefore starts empty, and `extract_one_url.py`'s skip-if-exists never makes a
rerun look artificially fast. Nothing is deleted automatically, so the output
stays around to inspect; clear old runs yourself when scratch gets cluttered:

```bash
rm -rf /scratch/users/$USER/demo_results
```

## Comparing time and resources

The scripts don't print resource usage themselves — that's Slurm accounting's
job, queried after a job finishes. `MaxRSS` is the peak RAM actually used
(compare against the `ReqMem` you asked for); `TotalCPU` vs. `Elapsed` shows
how well the reserved cores were kept busy:

```bash
sacct -j <jobid> --format=JobID,JobName,Elapsed,TotalCPU,AllocCPUS,ReqMem,MaxRSS,State
```

Or the one-screen efficiency summary (CPU efficiency and memory utilization,
per job or per array task):

```bash
seff <jobid>        # seff 12345678, or seff 12345678_1 for one array task
```

*Co-authored by Claude (Opus 4.8).*
