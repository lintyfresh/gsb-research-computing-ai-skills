---
layout: default
title: "Day 4 Challenge"
parent: "Day 4 — Parallelization & Local LLMs"
nav_order: 7
permalink: /day4/putting-it-all-together/
---

# Day 4 Challenge

<div data-room-id="d4-capstone"></div>

This capstone combines everything from the week into one pipeline — all at once.

---

## The Challenge

**1. Process *every* filing with a job array.**
In [Slurm Job Arrays](../slurm-arrays/) you ran 100 filings through an array, one filing per task. Now do all of them: `data/aws_links.csv` lists **992**.

Keep using `gemini-2.5-flash` through the Stanford AI API Gateway, and build on the `scripts/extract_array.py` and `slurm/extract_array.slurm` you already wrote.

The catch is that the Yens cap a job array at **512 tasks** — see for yourself:

```bash
scontrol show config | grep -i MaxArraySize
```

So one filing per task is no longer available to you. Deciding how many tasks to ask for, and how to divide 992 filings among them, is the challenge.

{: .tip }
> Claude Code may be helpful here — ask it to lay out different strategies for dividing the filings and assigning them to tasks, and what each one trades off.

**This is a good example of what scaling up to a real-world workload looks like: the approach that worked on a small run stops fitting, and you have to adapt it to the constraints of the machine.**

**2. Check how many filings actually landed.**
Count the results you ended up with. If it isn't 992, work out which are missing and why — then decide what you'd change so that a rerun doesn't start from nothing (see [Avoiding Wasteful Computation](../slurm-arrays/#exercise-avoiding-wasteful-computation)).

**3. Document it.**
Keep adding to the same `README.md` you've been building since Day 1 — the one you wrote up for your pipeline in [Documenting Your Pipeline](../../day3/documenting-pipeline/). It should describe the latest state of the pipeline.

**4. Commit and push from the Yens.**

Ask Claude Code to handle it:

> Add and commit my array script and my README changes — not the extracted data — with a message like "Day 4 Challenge: all 992 filings", then push to my fork.

{: .note }
> Remember to apply a 🟢 green sticky note when you're done, and a 🔴 red sticky note if you need help.

<label class="quest-check"><input type="checkbox" data-room="d4-capstone" data-key="commit"> Completed the deliverables and pushed to GitHub</label>

---

## The Full Stack You've Built

Every row in this table is a tool you used this week and where you learned it — in the order you met them, from Day 1 to Day 4.

| Layer | Tool | Where you learned it |
|-------|------|---------------------|
| Shell & files | CLI + wildcards + scp | Day 1 — Command Line Basics, Bulk File Operations, Transferring Files |
| Remote access | SSH | Day 1 — Connecting to a Cluster |
| Version control | Git fork → commit → push | Day 1 — Version Control with Git |
| Python environment | venv + pip + dotenv | Day 2 — environment setup |
| LLM extraction | Stanford AI API Gateway + Pydantic | Day 2 — structured extraction |
| Data governance | 3-bucket privacy rule | Day 2 — data classification |
| Batch jobs | Slurm `sbatch` + profiling | Day 3 — batch jobs |
| Documentation | README + project layout | Day 3 — reproducibility |
| Parallel scaling | Slurm job arrays | Day 4 — Slurm Job Arrays |
| Fault tolerance | Skip work already done on rerun | Day 4 — Slurm Job Arrays |
| GPU computing | GPU via `--gres=gpu:1` | Day 4 — How to Run LLMs on the Yens |
| Local LLMs | Ollama on cluster hardware | Day 4 — How to Run LLMs on the Yens |
| Handling failures | Validation + comparing across models | Day 4 — Handling LLM Failure Modes |

---

## Final Sync

This is the last sync — make it count. Go back through Day 4 and check any quests you finished but didn't tick, then run the `./cast` spell from the **Cast to the leaderboard** button on the last one you checked — each spell carries your running total, so the most recent cast is the one that counts.

The leaderboard updates within a couple of minutes — this is your final rank.

---

{: .important }
> **That's all four days.**
>
> Check the leaderboard to see where you finished.
>
> Plenty is left over: [Sherlock](https://www.sherlock.stanford.edu/) and [Marlowe](https://docs.marlowe.stanford.edu/), two of [Stanford's other compute clusters](https://srcc.stanford.edu/systems/clusters); [Redivis](https://rcpedia.stanford.edu/_user_guide/redivis/), the platform behind Stanford's [Data Farm](https://stanford.redivis.com/); LLM fine-tuning; multi-node jobs. Which of those matter will depend on what your research needs.
