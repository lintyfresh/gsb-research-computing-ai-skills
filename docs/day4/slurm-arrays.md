---
layout: default
title: "Slurm Job Arrays"
parent: "Day 4 — Parallelization & Local LLMs"
nav_order: 2
permalink: /day4/slurm-arrays/
---

# Slurm Job Arrays

<div data-room-id="d4-slurm-arrays"></div>

We've seen when a workload qualifies for parallelization and when it helps. Now let's get more hands-on: *how* to implement it on the Yens. There are a few ways to run work in parallel on a cluster; for embarrassingly parallel jobs like ours, a standard tool is a **Slurm job array**.

---

## Recap: One Script, One Task

On Day 3 you didn't run your script directly on a login node — you handed it to **Slurm**, the cluster's scheduler, in an `sbatch` script. Slurm found a free slot on a compute node, ran your job there, and saved the output. That was one input, one job.

{: .demo }
> For example, consider the following:
>
> ```bash
> #!/bin/bash
> #SBATCH --job-name=hello
> #SBATCH --output=logs/hello_%j.out
> #SBATCH --error=logs/hello_%j.err
> #SBATCH --time=00:01:00
> #SBATCH --mem=1G
> #SBATCH --cpus-per-task=1
>
> echo "Hello, world!"
> ```
>
> If we submit this, we can inspect the log file to see that the compute node printed:
>
> ```
> Hello, world!
> ```

---

## One Script, Many (Similar) Tasks

Now suppose we want to run that script not once but many times. Each run is independent of the others, so rather than one core working through them in sequence, we want many running at once.

You *could* do that by hand, submitting the script once for each run — a separate `sbatch` call, job ID, and output file every time. That's fine for four but unmanageable for a hundred. Slurm has a purpose-built tool for exactly this pattern instead.

{: .demo }
> Now the same script as an array, with one directive added:
>
> ```bash
> #!/bin/bash
> #SBATCH --job-name=hello-array
> #SBATCH --output=logs/hello_%A_%a.out
> #SBATCH --error=logs/hello_%A_%a.err
> #SBATCH --time=00:01:00
> #SBATCH --mem=1G
> #SBATCH --cpus-per-task=1
> #SBATCH --array=1-4                     # the new line, which says: run this script 4 times
>
> echo "Hello, world! My task number is $SLURM_ARRAY_TASK_ID"
> ```
>
> After submitting this job array, we should be able to see the following in the different log files:
>
> ```
> Hello, world! My task number is 1
> Hello, world! My task number is 2
> Hello, world! My task number is 3
> Hello, world! My task number is 4
> ```

{: .note }
> **`%A` and `%a` in the log names.** On Day 3 you used `%j`, the job ID, so each run wrote its own log file. An array needs two numbers instead: `%A` is the ID of the array as a whole, and `%a` is the task's index within it. Together they give every task a file of its own — for example, `hello_402103_1.out`, `hello_402103_2.out`, and so on — rather than four tasks overwriting one another.

We can see that specifying your job as an **array** tells Slurm to launch your one script many times, each run as an independent **task**.

<svg viewBox="0 0 618 270" role="img" aria-labelledby="array-title array-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:616px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="array-title">One array script fans out into many tasks</title>
  <desc id="array-desc">A single submission script with the directive array equals 1 to N fans out into N independent tasks, numbered 1, 2, 3 and so on up to N. What each task does is determined by your code together with its array task ID.</desc>
  <!-- fan-out connectors (drawn first, behind boxes) -->
  <line x1="188" y1="129" x2="330" y2="37"  stroke="#cbd3e0" stroke-width="1.5"/>
  <line x1="188" y1="129" x2="330" y2="89"  stroke="#cbd3e0" stroke-width="1.5"/>
  <line x1="188" y1="129" x2="330" y2="141" stroke="#cbd3e0" stroke-width="1.5"/>
  <line x1="188" y1="129" x2="330" y2="221" stroke="#cbd3e0" stroke-width="1.5"/>
  <rect x="24" y="103" width="164" height="52" rx="10" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="106" y="124" font-size="12.5" font-weight="700" fill="#2c3e50" text-anchor="middle">Slurm script</text>
  <text x="106" y="142" font-size="10.5" fill="#6a7280" text-anchor="middle" font-family="ui-monospace, SFMono-Regular, Menlo, monospace">--array=1–N</text>
  <rect x="330" y="15" width="264" height="44" rx="8" fill="#eef5ff" stroke="#bcd4f2" stroke-width="1.5"/>
  <text x="462" y="31" font-size="12" fill="#2c3e50" text-anchor="middle">task 1</text>
  <text x="462" y="46" font-size="8" fill="#6a7280" text-anchor="middle">determined by your code <tspan font-weight="700">and</tspan> SLURM_ARRAY_TASK_ID</text>
  <rect x="330" y="67" width="264" height="44" rx="8" fill="#eef5ff" stroke="#bcd4f2" stroke-width="1.5"/>
  <text x="462" y="83" font-size="12" fill="#2c3e50" text-anchor="middle">task 2</text>
  <text x="462" y="98" font-size="8" fill="#6a7280" text-anchor="middle">determined by your code <tspan font-weight="700">and</tspan> SLURM_ARRAY_TASK_ID</text>
  <rect x="330" y="119" width="264" height="44" rx="8" fill="#eef5ff" stroke="#bcd4f2" stroke-width="1.5"/>
  <text x="462" y="135" font-size="12" fill="#2c3e50" text-anchor="middle">task 3</text>
  <text x="462" y="150" font-size="8" fill="#6a7280" text-anchor="middle">determined by your code <tspan font-weight="700">and</tspan> SLURM_ARRAY_TASK_ID</text>
  <text x="462" y="188" font-size="16" fill="#9aa2b1" text-anchor="middle">⋮</text>
  <rect x="330" y="199" width="264" height="44" rx="8" fill="#eef5ff" stroke="#bcd4f2" stroke-width="1.5"/>
  <text x="462" y="215" font-size="12" fill="#2c3e50" text-anchor="middle">task N</text>
  <text x="462" y="230" font-size="8" fill="#6a7280" text-anchor="middle">determined by your code <tspan font-weight="700">and</tspan> SLURM_ARRAY_TASK_ID</text>
  <!-- caption -->
  <text x="309" y="263" font-size="12.5" fill="#6a7280" text-anchor="middle">One submission becomes N independent tasks, each with its own task ID.</text>
</svg>

The task number is what makes this general. Every task runs the identical script, and `SLURM_ARRAY_TASK_ID` is the only thing that differs between them — so wherever the work needs to vary, you derive it from that number: which file to read, which row of a list to process, which parameter value to try.

{: .warning }
> **Counting from 1.** `--array=1-N` numbers the tasks 1, 2, … N. Slurm doesn't insist on that: numbering from 0 instead, so the tasks run 0 through N − 1, is equally valid. But starting at 1 is the convention used here, and it matters as soon as the task ID indexes something. In some languages a list of N items, `items`, is indexed 0 through N − 1, so a 1-based task ID has to be shifted — `items[task_id - 1]` rather than `items[task_id]`. Get it wrong and nothing complains up front: the first item is silently skipped, and the last task runs off the end of the list.

<label class="quest-check"><input type="checkbox" data-room="d4-slurm-arrays" data-key="main"> I can explain what a Slurm job array is: one script, launched many times, each task identical except for its task ID</label>

---

## Exercise

Now over to you. Your job is the following: process and extract information from 100 SEC filings using a job array. The filings are hosted online, and their URLs are in `data/aws_links.csv` — the same file your Day 3 batch script read, already in your cloned repo.

You'll end up with two files: a new Python script that handles a single filing, and a Slurm script to launch it as an array — either a new one, or the `slurm/extract_form_3_batch.slurm` you wrote on Day 3, adapted.

{: .note }
> **Why this runs on `gemini-2.5-flash`.** Day 2 finished on the stronger `gpt-5.2`, following the rule *iterate cheap, then spend where it counts*. Day 3's batch script went back to the cheap model, and stays there today — because at a hundred filings the arithmetic flips: the same call runs a hundred times, so cost and speed become the thing you're managing. You get the rougher model in exchange, and handling that is part of the rest of today's work.

Work through it in four steps.

**1. Figure out how to associate each task with a filing.**

{: .note }
> **Getting the task ID into Python.** Slurm sets `SLURM_ARRAY_TASK_ID` in each task's environment. Your `.slurm` script passes it to your new Python script as a command-line argument:
>
> ```bash
> python scripts/extract_array.py "$SLURM_ARRAY_TASK_ID"
> ```
>
> and Python reads it back from `sys.argv` — a different number in every task:
>
> ```python
> import sys
>
> task_id = int(sys.argv[1])                      # 1, 2, … 100
> ```
>
> That's one way of doing it. The script could equally read the variable straight from its environment with `os.environ["SLURM_ARRAY_TASK_ID"]` and take no argument at all. Passing it in keeps the handover visible in the `.slurm`, and lets you run a single task by hand to test it.

<details markdown="1">
<summary>💡 Hint — one way to do it</summary>

Every task runs the same script and differs only in its task ID, so the script can do the lookup itself — read the filings out of `data/aws_links.csv` and take the one matching this task:

```python
import os
import sys

# Same pin as the Day 3 batch script, and it has to come before pandas is
# imported — see the note below for why an array makes it matter more.
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("OMP_NUM_THREADS", "1")

import pandas as pd

task_id = int(sys.argv[1])                      # handed over by the array script

# the CSV has a single `urls` column; drop any blank rows
urls = pd.read_csv("data/aws_links.csv")["urls"].dropna()

# keep only the filings themselves — the first row is the folder they live in,
# not a filing — and take the first 100
filings = [u for u in urls if u.endswith(".txt")][:100]

filing = filings[task_id - 1]                   # task_id == 1 implies take the first filing
```

That `- 1` is the off-by-one from the warning above: the tasks count from 1, the list from 0.

</details>

{: .note }
> **Keep the thread pin, and mean it here.** [Day 3](../../day3/profiling/) had you set `OPENBLAS_NUM_THREADS=1` so pandas' math libraries wouldn't grab every core on a shared node. That was one script against your own CPU limit. An array runs a hundred of them at once, each free to spawn a thread per core — so the same two lines are doing considerably more work now than they were when you first wrote them. They only take effect if they run *before* `import pandas`, which is why they sit at the very top.

**2. Given a filing, write the usual extraction code.** Nothing new here — fetch the filing, send it to the API, validate the response with your Pydantic model. It's the same logic you wrote on Day 2 and looped over on Day 3, except there's no loop: this task handles exactly one filing.

<details markdown="1">
<summary>💡 Hint — the extraction code, ready to copy</summary>

This is `scripts/extract_form_3_batch.py` — the script you profiled and scaled to 100 filings on Day 3 — with the loop taken out.

That really is the whole change. Day 3's version read `aws_links.csv` itself and looped over every filing in turn; here step 1 has already used the task ID to pick your one filing out of that same CSV, so what's left is the body of that loop and nothing else. Same model, same schema, same prompt, same fetch over the network. **The array is what replaces the loop** — a hundred copies of this running side by side, instead of one copy going round a hundred times.

```python
import json
import os

import requests
from openai import OpenAI
from pydantic import BaseModel
from typing import List
from dotenv import load_dotenv

load_dotenv()
client = OpenAI(
    base_url="https://aiapi-prod.stanford.edu/v1",
    api_key=os.getenv("STANFORD_API_KEY"),
)


class Form3Filing(BaseModel):
    insider_name: str
    insider_role: List[str]
    company_name: str
    company_cik: str
    filing_date: str


system_prompt = """
You are a data extraction agent for SEC Form 3 filings.

Extract the following fields:
- insider_name: The name of the insider (from reportingOwner or anywhere in the document).
- insider_role: A list of roles the insider holds (Director, Officer, 10% Owner, Other).
- company_name: The issuer's company name.
- company_cik: The CIK number of the issuer (from issuerCik or COMPANY DATA).
- filing_date: The filing date (prefer signatureDate or FILED AS OF DATE).

Return valid JSON matching the schema exactly.
Return a SINGLE JSON object, not a list. Do not wrap it in an array.
"""

# `filing` is the URL you picked in step 1 — fetch it over the network
filing_text = requests.get(filing).text

api_response = client.chat.completions.create(
    model="gemini-2.5-flash",
    response_format={"type": "json_object"},
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": filing_text},
    ],
)

# validate the reply against the schema before trusting it
result = Form3Filing.model_validate_json(api_response.choices[0].message.content)
```

</details>

**3. Save the output to its own file,** so the result says what it came from and no two tasks write to the same place.

<details markdown="1">
<summary>💡 Hint — one way to do it</summary>

Name it after the filing, the way the Day 3 batch script does:

```python
from pathlib import Path

name = filing.split("/")[-1].replace(".txt", ".json")
output_path = Path("results") / name         # results/0000003570-22-000041.json
```

</details>

**4. Have the Slurm array script invoke your new Python script,** handing over the task ID as its argument:

```bash
python scripts/extract_array.py "$SLURM_ARRAY_TASK_ID"
```

{: .note }
> **Two things not to forget.** That line only works once the environment is ready, so the script still needs to `cd` to the repo root and activate the virtual environment first — the same two lines you wrote on Day 3. And the `#SBATCH --array=` directive has to be up with the other directives at the top: without it you've submitted one ordinary job, not an array, and `SLURM_ARRAY_TASK_ID` won't be set at all.

Then submit it and watch it run. `watch` re-runs a command every couple of seconds, so you can see the tasks start in parallel and drop off as they finish:

```bash
sbatch slurm/extract_array.slurm
watch squeue --me
```

The new thing to notice is the job IDs: an array shows up as many rows sharing one ID, with a task number after it. So if `sbatch` printed job `12345678`, its tasks appear as `12345678_1`, `12345678_2`, and so on — that number is just an example, yours will be different. Each task moves through the same `PD` → `R` → gone lifecycle you watched on [Day 3](../../day3/slurm-scheduler/). Once it's done, check the per-task logs in `logs/` and the results in `results/`.

{: .note }
> Remember to apply a 🟢 green sticky note when you're done, and a 🔴 red sticky note if you need help.

<label class="quest-check"><input type="checkbox" data-room="d4-slurm-arrays" data-key="exercise"> I submitted a job array, watched the tasks run in `squeue`, and confirmed it finished with one result file per filing</label>

---

## Optional Practice: Combine the Results into One CSV

The array leaves you a directory of JSON files, one per filing. For analysis you want a single table instead — one row per filing, one column per field.

Write a short script that reads every JSON in `results/` and writes them out as one CSV.

*Think before you type: what happens to a task that failed and never wrote a file?*

<details markdown="1">
<summary>Solution (expand after trying)</summary>

```python
# scripts/merge_results.py — combine the array's per-filing JSON into one CSV
import json
from pathlib import Path

import pandas as pd

RESULTS_DIR = Path("results")
OUTPUT_CSV = Path("results/extracted_filings.csv")

rows = []
for f in sorted(RESULTS_DIR.glob("*.json")):
    data = json.loads(f.read_text())
    data["filing"] = f.stem          # keep a record of which filing each row came from
    rows.append(data)

df = pd.DataFrame(rows)
df.to_csv(OUTPUT_CSV, index=False)

print(f"Wrote {len(df)} rows to {OUTPUT_CSV}")
```

A failed task simply left no file, so it never turns up in the glob and nothing crashes. That's also why the count matters: if `len(df)` is less than 100, some tasks didn't finish.

</details>

<label class="quest-check"><input type="checkbox" data-room="d4-slurm-arrays" data-key="side1"> Optional practice complete</label>

---

## Why a Job Array Beats a Loop

Day 3 did this same work with a `for` loop inside a single job. Two things change:

- **The filings are processed at the same time, rather than one after another.** The loop worked through them in sequence on one core; a job array hands them to whatever cores are free — including in ["waves"](../parallelization/) when there are more filings than cores.
- **A failure costs you one filing, not the rest of the run.** `extract_form_3_batch.py` has no error handling, so an exception at filing 40 ends the script and filings 41 to 100 never run at all. In a job array, task 40 fails and the other 99 finish regardless.

What doesn't change is how much you have to keep track of. It's still one job ID, one `squeue` line to watch and one `scancel` to stop the lot — now with per-task sub-IDs underneath.

---

## Exercise: Avoiding Wasteful Computation

A job array limits the *damage* of a failure, as we just saw — but you still have to redo whatever failed. A node reboots, a task hits its time limit, the API times out, and a handful of your 100 come back empty. Rerunning the whole array to catch them wastes compute, and with a paid API, money.

The fix is to make each task safe to run again. Before doing any work, a task should check whether its output already exists and exit if it does. Now if you resubmit the *same* array after a partial failure, the finished tasks stop immediately; only the missing ones do real work.

Add this check to your script, then resubmit the array you just ran.

<details markdown="1">
<summary>💡 Hint — one way to do it</summary>

```python
# already done? skip — makes the array safe to resubmit after a partial failure
if output_path.exists():
    print(f"{output_path} already exists — skipping")
    sys.exit(0)
```

</details>

Nothing has been deleted, so every task should find its output and exit at once — the whole array finishing in seconds rather than minutes is the sign it worked.

<label class="quest-check"><input type="checkbox" data-room="d4-slurm-arrays" data-key="resubmit"> I added the skip-if-exists check, resubmitted the array, and saw the finished tasks exit immediately</label>

---

## What You Learned

- You can explain what a Slurm **job array** is: one script, submitted once, that Slurm runs as many independent tasks
- You know that `#SBATCH --array=1-N` creates the tasks and `SLURM_ARRAY_TASK_ID` distinguishes them, and how to hand that number to a Python script
- You can map a task ID to a unit of work — here, for instance, reading the filings from `data/aws_links.csv` and indexing into them, minding that tasks count from 1 and lists from 0
- You've submitted an array, watched the tasks move through `squeue`, and found each one's output in its own `%A_%a` log
- You know how to make a task safe to rerun — skip it if its output already exists — so a partially failed array only redoes the missing work
- You can say why a job array beats the Day 3 loop: the filings are processed at the same time, and one failure costs you one filing rather than the rest of the run
