# GSB Research Computing & AI Skills

> **Stanford GSB DARC · Research computing & AI skills for GSB researchers · 4 days · Hands-on**

A four-day hands-on course covering the command line, the Yens cluster, SLURM, GPU jobs, LLM APIs, and AI coding tools. The course runs as a game — complete rooms, earn skills, and take on optional challenges.

**🌐 Course website:** <https://gsbdarc.github.io/gsb-research-computing-ai-skills/>

> Forked this repo? Once you enable GitHub Pages on your fork, your own copy of the site lives at `https://YOUR-USERNAME.github.io/gsb-research-computing-ai-skills/` — that's the one that tracks your progress and leaderboard rank.

---

## What You'll Learn

| Day | Focus | Skills |
|-----|-------|--------|
| **Day 1** | Foundations | CLI · SSH · Yens file system · Git · Claude Code |
| **Day 2** | Python & AI tools | JupyterHub · Python envs & reproducible venvs · AI Playground · Secure key management · Pydantic · LLM-as-a-judge · AI agents & data privacy |
| **Day 3** | Cluster computing | SLURM · Resource estimation · Job lifecycle · Job monitoring |
| **Day 4** | Parallelization & local LLMs | Parallelization · Job arrays · Local LLMs on cluster hardware · GPU vs CPU · LLM failure modes & validation |

## Resource Profile

### extract_form_3_batch.py — 10 filings (measured)

From `sacct -j 422951` — the Slurm job that produced the JSONs in `results/`:

- Yen node used: Yen4
- Wall-clock time (Elapsed): 12 s
- CPU time (TotalCPU): 1.3 s — about 11% of one core
- CPU cores used: 1
- RAM used (MaxRSS): 127 MB *(the job requested 1G; 127 MB is what it actually used)*
- Serial or parallel: serial, I/O-bound — almost all of the 12 s is spent waiting on the Stanford AI API

### What scales with the number of filings — and what doesn't

The loop is serial: one blocking API call per filing, waiting for each answer before starting the next.

- **Scales linearly:** wall-clock time, total CPU-seconds, number of API calls (and cost), number of output files.
- **Stays flat:** RAM and core count. Each filing's text (~7 KB) is replaced on the next iteration, and results are written straight to `results/` instead of being collected in a list, so nothing accumulates. Most of the 127 MB is the Python interpreter plus the pandas/openai/pydantic imports — a fixed cost whether you run 10 filings or 1000.

### extract_form_3_batch.py — 100 filings (estimate, written before the run)

- Wall-clock time: ~2 min expected, up to ~4 min if the API is slower than it was for the 10-filing run
- CPU time: ~13 s
- CPU cores: 1 — extra cores can't help a serial loop
- RAM: ~130 MB
- Requested in Slurm: `--partition=dev`, `--time=00:10:00`, `--mem=1G`, `--cpus-per-task=1`

The `--time` request is well above the estimate on purpose: it's a kill deadline rather than a reservation, and API latency is the one thing here that isn't bounded. Ten minutes is ~5× the expected runtime.

### extract_form_3_batch.py — 100 filings (actual)

From `sacct -j 424588 --format=JobID,State,Elapsed,TotalCPU,MaxRSS,ReqMem`:

- State: **FAILED** — got through 28 of 100 filings, then died on filing 29
- Wall-clock time (Elapsed): 1 min 31 s (for 28 filings)
- CPU time (TotalCPU): 1.8 s — about 2% of one core
- RAM used (MaxRSS): 90 MB (`91736K`), against 1 G requested
- Partition: `dev`, `--time=00:10:00` — the time limit was never the problem

**Why it failed:** not a resource shortfall. The Stanford AI API returned HTTP 429 —
a tokens-per-minute rate limit on the shared class key (`over available TPM=0`).
The script has no retry and no error handling, so the first 429 aborted the run.
The 28 completed JSONs were already written to `results/` and survived.

**Over- or under-estimated:**

| Resource | Estimated | Actual | Verdict |
|---|---|---|---|
| Wall clock | ~2 min / 100 (1.2–2.3 s per filing) | 3.25 s per filing → ~5.5 min / 100 | **Under-estimated ~2.7×** |
| CPU time | ~13 s / 100 | 0.064 s per filing → ~6.4 s / 100 | Over-estimated ~2× |
| Cores | 1 | 1, at ~2% utilization | Correct |
| RAM | ~130 MB | 90 MB | Over-estimated ~1.4× (and 11× over the 1 G requested) |

**What I got wrong and why.** The wall-clock miss is the interesting one: I
extrapolated from job 422951, which ran when the API was quiet. By the time this
job ran the whole class was hitting the same endpoint, so each call took longer —
per-filing time on an I/O-bound job is a property of *how busy the API is*, not of
my code. Extrapolating a network-bound runtime from a single quiet-period
measurement is the mistake to avoid next time.

The RAM prediction was over-cautious in a useful direction, and it confirms the
flat-vs-scaling reasoning above: this run processed **2.8× more filings than the
10-filing baseline and used *less* RAM** (90 MB vs 127 MB). Memory genuinely
doesn't track filing count — the variation is just interpreter and import
overhead.

**The real lesson:** at this scale the binding constraint wasn't CPU, RAM, or
walltime — it was an external API quota, which no `#SBATCH` line can size for.
Resuming would need a skip-if-exists check so a rerun doesn't redo the finished 28.

---

## Parallelizing with a Slurm Job Array

The serial run above left 72 of 100 filings unprocessed. Rather than resubmit the
loop, the same work was rebuilt as a **job array** — `scripts/extract_array.py` and
`slurm/extract_array.slurm`, one filing per task, `--array=1-100`.

### extract_array.slurm — 100 filings (actual)

Array job **424743**, from `sacct -j 424743 -X --format=JobID,State,Elapsed,MaxRSS`:

- State: **100 of 100 tasks COMPLETED**, 0 FAILED
- 29 tasks skipped (output already existed), 71 did real extraction
- Array wall clock: **26 s** end to end (10:20:13 → 10:20:39)
- Per-task elapsed: 16 s for a skip, up to 37 s for an extraction
- CPU time per task: ~0.9–6 s
- RAM per task (MaxRSS): 70–99 MB
- Spread across 2 nodes (`yen10`, `yen20`), `--partition=normal`
- Errors: **none** — not a single 429 in any of the 100 `.err` files

### Serial loop vs. job array — same 100 filings

| | Serial (job 424588) | Array (job 424743) |
|---|---|---|
| Wall clock | ~5.5 min projected; died at 91 s | **26 s** |
| Filings completed | 28 of 100, then aborted | **100 of 100** |
| Effect of one failure | Kills the run; all later filings lost | Costs that one task only |
| RAM | 90 MB (one process) | 70–99 MB per task, 2 nodes |

Roughly a **12× speedup** on wall clock, and — the part that actually mattered — it
finished instead of aborting partway.

### What the numbers show

- **The array's real win is isolation, not just speed.** The serial run lost 72
  filings to a single unhandled exception. In the array each task stands alone, so
  the same failure would have cost one filing out of a hundred.
- **Skip-if-exists made the rerun free.** The 29 already-extracted filings exited
  without spending an API call, so re-running the full array cost nothing for work
  already done. That is what makes the array safe to resubmit after a partial failure.
- **The 429 never recurred — by luck, not by design.** The shared TPM quota had
  recovered before this run, and 71 near-simultaneous calls went through clean. The
  same submission an hour earlier would have hit the wall harder than the serial run
  did, since concurrency multiplies demand against one shared key. Nothing in this
  design prevents that; the skip logic just makes recovery cheap.
- **Startup dominates each task.** Skip-only tasks took 16 s against ~28 s for real
  extractions — so most of every task was Python importing pandas/openai for ~3 s of
  API work. Paying that import cost 100 times is the tradeoff of one-filing-per-task,
  and it's why the Day 4 Challenge chunks multiple filings into each task instead.

### Gotcha: Slurm resolves log paths from the submit directory

This array was submitted from inside `slurm/`, so `--output=logs/...` resolved to
`slurm/logs/`, not the repo-root `logs/` where the Day 3 jobs wrote. The
`cd $HOME/...` inside the script does **not** affect this — Slurm expands the log
paths at submission time, before the script body runs. Submit from the repo root to
keep all job logs in one place. Note that Slurm will not create the directory: if it
is missing the job fails immediately, with nowhere to write the error saying so.

---

## Day 4 Challenge — all 992 filings

`data/aws_links.csv` holds **992** filings, and the Yens cap a job array at 512 tasks
(`scontrol show config | grep MaxArraySize`). So one filing per task no longer fits.

**Chunking:** 2 filings per task → 992 ÷ 2 = **496 tasks**, exactly, no remainder.
Verified before submitting that the 496 slices cover all 992 filings once each, with
task 496 ending cleanly at position 992.

Built as `scripts/extract_array_all.py` + `slurm/extract_array_all.slurm`, kept
separate from the 100-filing pair. Three things carried over or added:

- **Skip-if-exists per filing**, not per task — a task whose first filing is done and
  second isn't must still do the second.
- **`try/except` per filing** — with 2 filings per task, an unhandled error on the
  first would otherwise cost the second as well.
- **Non-zero exit if any filing failed**, so `sacct` State stays meaningful. Without
  it, a task that swallowed both its errors would report `COMPLETED`.

### extract_array_all.slurm — actual (job 425458)

- 496 tasks, `--array=1-496`, no `%N` concurrency cap
- Array wall clock: **87 s** (10:53:33 → 10:55:00)
- Per-task elapsed: 13–15 s for most tasks
- RAM per task (MaxRSS): 72–91 MB
- Task states: 162 `COMPLETED`, **334 `FAILED`**

| Outcome | Filings |
|---|---|
| Extracted this run | 277 |
| Skipped (already done) | 102 |
| **Failed** | **613** — 612 `RateLimitError`, 1 `InternalServerError` |
| Total | 992 |

**Pipeline state: 379 / 992 extracted, 613 remaining.**

### What went wrong: the opening burst

The run was submitted without a concurrency cap, so the QoS limit of 100 concurrent
jobs applied and 100 tasks fired their first API call at essentially the same instant
— roughly 200K input tokens at once (~2K tokens per ~7 KB filing). The shared class
key's per-minute token budget was gone in seconds, and the whole array drained in 87 s,
far faster than the quota could replenish.

The failure distribution shows it happening:

```
tasks   1-100: saved= 98  skipped=102  failed=  0
tasks 101-200: saved=162  skipped=  0  failed= 38
tasks 201-300: saved= 17  skipped=  0  failed=183
tasks 301-400: saved=  0  skipped=  0  failed=200
tasks 401-496: saved=  0  skipped=  0  failed=192
```

The first ~150 tasks succeed, then the budget runs out and everything past task ~300
fails outright.

A `time.sleep(2)` between the two filings in a task was included, on the theory it
would ease the rate limit. It didn't, and the reason is worth recording: **the pause
spaces the calls a single task makes in sequence, but the limit is driven by how many
tasks run at once.** With 100 tasks concurrent, all of their *first* calls land
simultaneously and the pause never enters into it. Intra-task spacing is the wrong
lever for an inter-task problem.

### The fix — not yet applied

Cap concurrency in `slurm/extract_array_all.slurm`:

```bash
#SBATCH --array=1-496%25        # %25 = at most 25 tasks running at once
```

25 concurrent tasks means ~50 calls in flight instead of ~200 — a rate the key
demonstrably sustained through the first 150 tasks of this run. Expect ~10 minutes
instead of 87 seconds, in exchange for landing most of the remaining 613 in a single
pass rather than burning quota across three or four.

Whether throttled or not, the recovery loop is the same, and it's cheap because the
array is idempotent: **submit → count results → resubmit → repeat until the count
stops rising.** The 379 finished filings skip without spending a call. If the count
plateaus well short of 992, the quota is dry and waiting beats resubmitting.

### What the error handling bought

334 tasks exited non-zero rather than falsely reporting success, every failure is
typed and attributed to a filing in `logs/extract_array_all_425458_*.err`, and no
partial or corrupt JSON was written. The counts reconcile exactly — 277 + 102 + 613 =
992 — so nothing was silently dropped. At this scale that reconciliation is the check
worth having: `sacct` alone would have said "334 failed" without telling you whether
that meant 334 filings or 668.