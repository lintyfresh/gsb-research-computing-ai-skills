---
layout: default
title: "How to Run LLMs on the Yens"
parent: "Day 4 — Parallelization & Local LLMs"
nav_order: 5
permalink: /day4/running-llms/
---

# How to Run LLMs on the Yens

<div data-room-id="d4-running-llms"></div>

The last section covered *why* you'd run a model yourself. This is a high-level overview of *how*: loading an open model onto the cluster, starting a server that holds it, and running queries against that server — potentially on a GPU (graphics processing unit), which makes inference (the work of running the model to produce an answer) much faster.

---

## The Three Steps, in Outline

At a high level, running a model on the cluster comes down to three things:

1. **Loading an open model onto the cluster.** Download the weights once and cache them on cluster storage, so nothing has to be fetched again on later runs.
2. **Starting a server that holds it.** Loading a model into memory takes time, so you pay that cost once and leave the process running, rather than reloading for every query.
3. **Running queries against that server.** From your own code, across the cluster's internal network — the request never leaves the Yens. The server does the work and sends back the answer.

**[Ollama](https://ollama.com/)** is the standard way to do all three, and what we use here. It downloads open-weight models, keeps one loaded in memory, and serves it behind an HTTP API.

---

## Exercise: Querying a Local LLM

We've already done the work for you of downloading a model — `llama3.2:1b`, Meta's **open-weight** Llama 3.2 at 1 billion parameters, freely downloadable by anyone — and setting up a server.

{: .note }
> **Setting up your own local LLM server.** There aren't enough GPUs on the Yens for everyone to hold one at once, and setting a server up takes time — so we won't have you each do it today. If you want to do it yourself later, every step is documented in [Running Ollama on Stanford Computing Clusters](https://rcpedia.stanford.edu/blog/2025/05/12/running-ollama-on-stanford-computing-clusters/).

To access this server, you'll need its URL, which corresponds to the node the server is on as well as a port (a numbered door into that machine — one node can be running many services at once, and the port is how you say which door you're knocking on).

**First, check you can reach the server.** The way you do this is by running the following command, substituting the URL we've given you:

```bash
curl <server-url>
```

You should see `Ollama is running` after running the command.

{: .note }
> That request left your node, crossed to another machine on the Yens, and came back — without leaving the cluster. The model runs there too, so your prompts and data never leave the Yens.

<label class="quest-check"><input type="checkbox" data-room="d4-running-llms" data-key="reach"> I reached the server and got `Ollama is running` back</label>

**Second, run a query on the LLM from Python.** You can do this interactively from your Yen login node, by running the following script, substituting your query:

```python
from openai import OpenAI

client = OpenAI(
    base_url="<server-url>/v1",              # the model server on the Yens
    api_key="ollama",                          # ignored, but the client requires a value
)

response = client.chat.completions.create(
    model="llama3.2:1b",
    messages=[{"role": "user", "content": "<your query>"}],
)
print(response.choices[0].message.content)
```

{: .note }
> The interface to the local LLM is **OpenAI-compatible**, so this is effectively the *same* code you used for the Stanford AI API Gateway on Day 2 — only the `base_url` changes.

{: .note }
> Remember to apply a 🟢 green sticky note when you're done, and a 🔴 red sticky note if you need help.

{: .warning }
> This only works while the server is running. To use a local LLM in the future, you'll have to set one up yourself.

<label class="quest-check"><input type="checkbox" data-room="d4-running-llms" data-key="query"> I submitted a query to the local LLM and got a response back</label>

---

## Running Local LLMs on Different Types of Hardware

{: .demo }
> You may have noticed that the server URL pointed to a GPU node on the Yens.
>
> Now let's run queries on a local LLM that's running on a **CPU** instead.
>
> We'll send the same query to each and time them — same model, same prompt, same code, with only the hardware underneath differing.
>
> What do you notice about the runtime?

<details markdown="1">
<summary>What we saw (expand after discussion)</summary>

The CPU still answers — but slower, and *how much* slower depends on:

- The prompt length;
- The length of the answer the model generates;
- The GPU and CPU — chip model, and how many cores the CPU has; and
- The model size.

A small difference per query can still be a meaningful one, for a task that runs a lot of them — a few seconds each becomes hours across thousands of queries.

And our example is on the favourable end for the CPU: a short query, of low complexity, against a small model. A longer prompt, a longer answer, or a bigger model all widen the gap.

</details>

We won't go into the details of why a GPU is faster than a CPU at running LLM queries. It's enough to say that the demo above illustrates GPUs are much faster in general — though we've also seen that a CPU may be enough for basic tasks.

{: .aside }
> The efficacy of GPUs for training LLMs and serving LLM queries has made them enormously valuable. Indeed, the surge in the share price of NVIDIA, the dominant GPU maker, tracks the AI boom:
>
> <svg viewBox="0 0 600 278" role="img" aria-labelledby="nvda-title nvda-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:600px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
>   <title id="nvda-title">NVIDIA share price over time</title>
>   <desc id="nvda-desc">A line chart of NVIDIA's split-adjusted year-end share price from 2016 to 2024. It stays low — a few dollars — through 2019, rises through 2021, dips in 2022, then climbs steeply in 2023 and 2024 as demand for AI GPUs surges, reaching about $134 by the end of 2024.</desc>
>   <text x="300" y="20" font-size="13" font-weight="700" fill="#2c3e50" text-anchor="middle">NVIDIA's share price</text>
>   <!-- y gridlines -->
>   <line x1="50" y1="171" x2="585" y2="171" stroke="#eef1f8" stroke-width="1"/>
>   <line x1="50" y1="93"  x2="585" y2="93"  stroke="#eef1f8" stroke-width="1"/>
>   <!-- axes -->
>   <line x1="50" y1="30"  x2="50"  y2="250" stroke="#b8bfcc" stroke-width="1.5"/>
>   <line x1="50" y1="250" x2="585" y2="250" stroke="#b8bfcc" stroke-width="1.5"/>
>   <!-- y labels -->
>   <text x="44" y="254" font-size="10" fill="#6a7280" text-anchor="end">$0</text>
>   <text x="44" y="175" font-size="10" fill="#6a7280" text-anchor="end">$50</text>
>   <text x="44" y="97"  font-size="10" fill="#6a7280" text-anchor="end">$100</text>
>   <!-- price line -->
>   <polyline points="55,246 121,242 186,245 252,241 318,230 383,204 449,227 514,172 580,39" fill="none" stroke="#0072B2" stroke-width="2.5"/>
>   <circle cx="55"  cy="246" r="3" fill="#0072B2"/>
>   <circle cx="121" cy="242" r="3" fill="#0072B2"/>
>   <circle cx="186" cy="245" r="3" fill="#0072B2"/>
>   <circle cx="252" cy="241" r="3" fill="#0072B2"/>
>   <circle cx="318" cy="230" r="3" fill="#0072B2"/>
>   <circle cx="383" cy="204" r="3" fill="#0072B2"/>
>   <circle cx="449" cy="227" r="3" fill="#0072B2"/>
>   <circle cx="514" cy="172" r="3" fill="#0072B2"/>
>   <circle cx="580" cy="39"  r="4" fill="#0072B2"/>
>   <text x="578" y="33" font-size="10" font-weight="700" fill="#0072B2" text-anchor="end">~$134</text>
>   <!-- x labels -->
>   <text x="55"  y="266" font-size="10" fill="#6a7280" text-anchor="middle">2016</text>
>   <text x="121" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2017</text>
>   <text x="186" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2018</text>
>   <text x="252" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2019</text>
>   <text x="318" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2020</text>
>   <text x="383" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2021</text>
>   <text x="449" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2022</text>
>   <text x="514" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2023</text>
>   <text x="580" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2024</text>
> </svg>

---

## Types of GPUs Available on the Yens

The Yens have several GPU types. For our purposes they differ mainly in one thing: **VRAM** (video random-access memory — the GPU's own memory), which sets a ceiling on how big a model you can load.

| GPU type | VRAM | Roughly good for |
|-----|------|------------------|
| A30 | 24 GB | small models, embeddings |
| A40 | 48 GB | mid-size models |
| H200 | 141 GB | large models |

A model's weights have to fit in VRAM, so VRAM — not disk or CPU RAM — is the binding constraint on which models you can run.

You request a GPU the same way you set any other resource in a Slurm script — a directive at the top:

```bash
#SBATCH --partition=gpu       # the GPU partition (confirm the name for your setup)
#SBATCH --gres=gpu:1          # request one GPU
```

Just like the `#SBATCH` directives you wrote on Day 3, this tells the scheduler what your job needs — here, one GPU. Match the partition name (and any specific-node targeting) to your cluster's current setup.

{: .tip }
> **For interactive work** — exploring, pulling a model, quick tests — you don't need a batch script. Grab a GPU node directly with `srun --pty`, the same command you used for a CPU allocation on [Day 3](../../day3/slurm-job/), plus the GPU flags:
>
> ```bash
> srun --partition=gpu --gres=gpu:1 --cpus-per-task=4 --mem=16G --time=01:00:00 --pty bash
> ```
>
> This drops you into a shell *on a GPU node* with one GPU reserved — run `nvidia-smi` to confirm. To pin a specific GPU type, add `--constraint="GPU_MODEL:<type>"`, substituting one of the types from the table above. Reach for an interactive session when you're exploring or testing; use a batch job for long or production runs that should queue unattended.

{: .warning }
> **Release it when you're done.** Type `exit` the moment your experimentation is complete. An interactive allocation holds the GPU for the *full* `--time` you requested — even while it sits idle at your shell prompt — so no one else can use that GPU until you exit or the time limit runs out. GPUs are scarce shared resources; don't sit on one you've finished with.

<label class="quest-check"><input type="checkbox" data-room="d4-running-llms" data-key="main"> I understand, at a high level, the GPUs available on the Yens and how to access them</label>

---

## What You Learned

- You know what running an LLM on the cluster involves: loading the weights, starting a server that holds the model, and querying that server
- You queried a model hosted on another node of the Yens from your own — and your prompt never left the cluster
- You know that pointing your code at a local model rather than the Stanford AI API Gateway is a change of `base_url`
- You've seen the same model answer on a GPU and on a CPU, and know the GPU is generally much faster
- You know that **VRAM** sets the ceiling on the model size a given GPU can load, and how the Yen GPUs compare
- You can request a GPU in a Slurm job with `--partition=gpu` and `--gres=gpu:1`, or interactively with `srun --pty`
- You know where the setup steps live if you want to serve a model yourself
