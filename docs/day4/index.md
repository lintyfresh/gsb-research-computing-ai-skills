---
layout: floor
title: "Day 4 — Parallelization & Local LLMs"
nav_order: 4
has_children: true
has_toc: false
permalink: /day4/
floor: 4
---

# Day 4 — Parallelization & Local LLMs

Day 4 scales yesterday's single Slurm job into a full research pipeline. You'll fan one script across many filings at once with **job arrays**, then meet **local LLMs** — models you run on the cluster yourself rather than calling over the internet — and see what it takes to serve one. From there, the ways LLMs fail, and what to do about them. The **Day 4 Challenge** closes the day, and the course, by pushing the array from a hundred filings to all of them.

**Duration:** ~3 hours

---

## Day 3 Recap

- Profiled the extraction script to measure its real time and memory needs
- Wrote and submitted `slurm/extract_form_3_batch.slurm` as a batch job, with `#SBATCH` directives grounded in those measurements
- Monitored the job with `squeue` and `sacct`, and documented the pipeline in `README.md`

Any questions about Day 1–3 before we move on?

---

## Sections

Work through the sections in order — later ones build on earlier ones, and the Day 4 Challenge draws on everything you've learned.

| Section | Format | What you'll learn |
|------|--------|-----------------|
| [Parallelization Basics](parallelization/) | 🖊️ Concept | What it means to run work in parallel, when it helps, and the three ways to split a job — across cores, across jobs, or both |
| [Slurm Job Arrays](slurm-arrays/) | 🖊️💻 Concept + Hands-on | One script, many tasks: `--array`, `SLURM_ARRAY_TASK_ID`, and making a task safe to rerun so a partial failure costs you only what failed |
| [Why Run LLMs on the Yens?](why-local-llms/) | 🖊️ Concept | When to run a model yourself on the Yens vs. calling a cloud API — privacy, cost, reproducibility, and open vs. proprietary models |
| [How to Run LLMs on the Yens](running-llms/) | 🖊️💻 Concept + Hands-on | The three steps — loading a model, serving it, querying it — then querying a shared server yourself, and seeing the same model answer on a GPU and on a CPU |
| [Handling LLM Failure Modes](validating-llm-outputs/) | 💻 Hands-on | The main ways LLMs fail — hallucination, inconsistency, a lack of guardrails — and how to make a pipeline more robust against them |
| [Day 4 Challenge](putting-it-all-together/) | 🔑 Capstone | Process every filing in the dataset with an array job — more filings than the scheduler allows tasks, so the mapping is yours to work out |
| [Staying In Touch](staying-in-touch/) | 🏛️ Community | Where to get help after the course — the `#gsb-yen-users` Slack, the DARC team, and patterns to build on |
