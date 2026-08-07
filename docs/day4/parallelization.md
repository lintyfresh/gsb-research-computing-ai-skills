---
layout: default
title: "Parallelization Basics"
parent: "Day 4 — Parallelization & Local LLMs"
nav_order: 1
permalink: /day4/parallelization/
---

# Parallelization Basics

<div data-room-id="d4-parallelization"></div>

Before you scale a job across the cluster, it helps to picture what "in parallel" actually means, when it works, and why it's usually the single biggest speedup available to you.

---

## When Parallelization Helps

Think back to [the kitchen from Day 3](../../day3/compute-environments/): your machine is a kitchen, and every CPU core is a burner.

Say you want four grilled cheeses. The steps *within* one sandwich mostly don't split: you can't grill a side before the cheese is on the bread — nearly every step needs the previous one finished. Put four cooks on a single sandwich and three of them stand around watching. And no matter how many cooks you hire, a sandwich that takes four minutes takes four minutes.

<svg viewBox="0 0 600 338" role="img" aria-labelledby="gc1-title gc1-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:598px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="gc1-title">Grilled cheese on one burner</title>
  <desc id="gc1-desc">One burner cooks four grilled cheeses one after another — a single burner box shows the four steps (get bread, put cheese on bread, grill one side, grill the other side) lighting up in sequence, with a note to repeat four times, one sandwich after another.</desc>
  <!-- panel A: one burner, the ×4 repetition shown vertically -->
  <text x="300" y="22" font-size="12.5" font-weight="700" fill="#2c3e50" text-anchor="middle">One burner, four grilled cheeses</text>
  <rect x="190" y="34" width="220" height="264" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="202" y="50" font-size="10" font-weight="700" fill="#8a93a3">Burner</text>
  <text x="207" y="64" font-size="8.5" font-weight="600" fill="#8a93a3">sandwich 1</text>
  <text x="180" y="87"  font-size="9" fill="#8a93a3" text-anchor="end">t = 1</text>
  <text x="180" y="119" font-size="9" fill="#8a93a3" text-anchor="end">t = 2</text>
  <text x="180" y="151" font-size="9" fill="#8a93a3" text-anchor="end">t = 3</text>
  <text x="180" y="183" font-size="9" fill="#8a93a3" text-anchor="end">t = 4</text>
  <rect x="205" y="70" width="190" height="26" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.06;0.08;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="300" y="87" font-size="11" fill="#2c3e50" text-anchor="middle">get bread</text>
  <rect x="205" y="102" width="190" height="26" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.04;0.06;0.12;0.14;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="300" y="119" font-size="11" fill="#2c3e50" text-anchor="middle">put cheese on bread</text>
  <rect x="205" y="134" width="190" height="26" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.10;0.12;0.18;0.20;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="300" y="151" font-size="11" fill="#2c3e50" text-anchor="middle">grill one side of sandwich</text>
  <rect x="205" y="166" width="190" height="26" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.16;0.18;0.24;0.26;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="300" y="183" font-size="11" fill="#2c3e50" text-anchor="middle">grill other side of sandwich</text>
  <!-- sandwiches 2–4: the same four steps, repeated vertically -->
  <text x="180" y="216" font-size="9" fill="#8a93a3" text-anchor="end">t = 5–8</text>
  <text x="180" y="248" font-size="9" fill="#8a93a3" text-anchor="end">t = 9–12</text>
  <text x="180" y="280" font-size="9" fill="#8a93a3" text-anchor="end">t = 13–16</text>
  <rect x="205" y="200" width="190" height="24" rx="6" fill="#f3f5fa" stroke="#cdd4e6" stroke-width="1.2" stroke-dasharray="4 3"><animate attributeName="fill" values="#f3f5fa;#f3f5fa;#fde9c8;#fde9c8;#f3f5fa;#f3f5fa" keyTimes="0;0.22;0.24;0.48;0.50;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="300" y="216" font-size="9.5" fill="#8a93a3" text-anchor="middle">sandwich 2 — same four steps</text>
  <rect x="205" y="232" width="190" height="24" rx="6" fill="#f3f5fa" stroke="#cdd4e6" stroke-width="1.2" stroke-dasharray="4 3"><animate attributeName="fill" values="#f3f5fa;#f3f5fa;#fde9c8;#fde9c8;#f3f5fa;#f3f5fa" keyTimes="0;0.46;0.48;0.72;0.74;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="300" y="248" font-size="9.5" fill="#8a93a3" text-anchor="middle">sandwich 3 — same four steps</text>
  <rect x="205" y="264" width="190" height="24" rx="6" fill="#f3f5fa" stroke="#cdd4e6" stroke-width="1.2" stroke-dasharray="4 3"><animate attributeName="fill" values="#f3f5fa;#f3f5fa;#fde9c8;#fde9c8;#f3f5fa;#f3f5fa" keyTimes="0;0.70;0.72;0.96;0.98;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="300" y="280" font-size="9.5" fill="#8a93a3" text-anchor="middle">sandwich 4 — same four steps</text>
  <!-- repeat annotation -->
  <text x="490" y="140" font-size="16" font-weight="700" fill="#8a93a3" text-anchor="middle">× 4</text>
  <text x="490" y="158" font-size="10" fill="#8a93a3" text-anchor="middle">one sandwich after another</text>
  <line x1="490" y1="170" x2="490" y2="250" stroke="#b3bccb" stroke-width="1.5"/>
  <polygon points="485,248 495,248 490,258" fill="#b3bccb"/>
  <text x="300" y="320" font-size="12.5" fill="#6a7280" text-anchor="middle">The four steps of one sandwich are a sequence — grilling can't start before assembly.</text>
</svg>

But the sandwiches don't depend on each other. Each is its own pan — get the bread, put on the cheese, grill one side, grill the other — and no sandwich needs anything from the others. Fire up four burners and lunch is ready in a quarter of the time.

<svg viewBox="0 0 600 216" role="img" aria-labelledby="gc2-title gc2-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:598px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="gc2-title">Grilled cheese on four burners</title>
  <desc id="gc2-desc">Four burner boxes side by side each run the same four steps at the same time, cooking all four sandwiches at once.</desc>
  <!-- panel B: four burners -->
  <text x="300" y="22" font-size="12.5" font-weight="700" fill="#2c3e50" text-anchor="middle">Four burners, four grilled cheeses</text>
  <text x="38" y="70" font-size="9" fill="#8a93a3" text-anchor="end">t = 1</text>
  <text x="38" y="100" font-size="9" fill="#8a93a3" text-anchor="end">t = 2</text>
  <text x="38" y="130" font-size="9" fill="#8a93a3" text-anchor="end">t = 3</text>
  <text x="38" y="160" font-size="9" fill="#8a93a3" text-anchor="end">t = 4</text>
  <rect x="44" y="32" width="128" height="142" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="52" y="46" font-size="8.5" font-weight="700" fill="#8a93a3">Burner 1</text>
  <rect x="50" y="54" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.06;0.08;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="108" y="70" font-size="7.5" fill="#2c3e50" text-anchor="middle">get bread</text>
  <rect x="50" y="84" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.04;0.06;0.12;0.14;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="108" y="100" font-size="7.5" fill="#2c3e50" text-anchor="middle">put cheese on bread</text>
  <rect x="50" y="114" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.10;0.12;0.18;0.20;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="108" y="130" font-size="7.5" fill="#2c3e50" text-anchor="middle">grill one side of sandwich</text>
  <rect x="50" y="144" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.16;0.18;0.24;0.26;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="108" y="160" font-size="7.5" fill="#2c3e50" text-anchor="middle">grill other side of sandwich</text>
  <rect x="182" y="32" width="128" height="142" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="190" y="46" font-size="8.5" font-weight="700" fill="#8a93a3">Burner 2</text>
  <rect x="188" y="54" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.06;0.08;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="246" y="70" font-size="7.5" fill="#2c3e50" text-anchor="middle">get bread</text>
  <rect x="188" y="84" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.04;0.06;0.12;0.14;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="246" y="100" font-size="7.5" fill="#2c3e50" text-anchor="middle">put cheese on bread</text>
  <rect x="188" y="114" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.10;0.12;0.18;0.20;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="246" y="130" font-size="7.5" fill="#2c3e50" text-anchor="middle">grill one side of sandwich</text>
  <rect x="188" y="144" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.16;0.18;0.24;0.26;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="246" y="160" font-size="7.5" fill="#2c3e50" text-anchor="middle">grill other side of sandwich</text>
  <rect x="320" y="32" width="128" height="142" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="328" y="46" font-size="8.5" font-weight="700" fill="#8a93a3">Burner 3</text>
  <rect x="326" y="54" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.06;0.08;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="384" y="70" font-size="7.5" fill="#2c3e50" text-anchor="middle">get bread</text>
  <rect x="326" y="84" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.04;0.06;0.12;0.14;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="384" y="100" font-size="7.5" fill="#2c3e50" text-anchor="middle">put cheese on bread</text>
  <rect x="326" y="114" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.10;0.12;0.18;0.20;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="384" y="130" font-size="7.5" fill="#2c3e50" text-anchor="middle">grill one side of sandwich</text>
  <rect x="326" y="144" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.16;0.18;0.24;0.26;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="384" y="160" font-size="7.5" fill="#2c3e50" text-anchor="middle">grill other side of sandwich</text>
  <rect x="458" y="32" width="128" height="142" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="466" y="46" font-size="8.5" font-weight="700" fill="#8a93a3">Burner 4</text>
  <rect x="464" y="54" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.06;0.08;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="522" y="70" font-size="7.5" fill="#2c3e50" text-anchor="middle">get bread</text>
  <rect x="464" y="84" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.04;0.06;0.12;0.14;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="522" y="100" font-size="7.5" fill="#2c3e50" text-anchor="middle">put cheese on bread</text>
  <rect x="464" y="114" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.10;0.12;0.18;0.20;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="522" y="130" font-size="7.5" fill="#2c3e50" text-anchor="middle">grill one side of sandwich</text>
  <rect x="464" y="144" width="116" height="24" rx="6" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.2"><animate attributeName="fill" values="#eef1f8;#eef1f8;#fde9c8;#fde9c8;#eef1f8;#eef1f8" keyTimes="0;0.16;0.18;0.24;0.26;1" dur="14s" repeatCount="indefinite"/></rect>
  <text x="522" y="160" font-size="7.5" fill="#2c3e50" text-anchor="middle">grill other side of sandwich</text>
  <text x="300" y="198" font-size="12.5" fill="#6a7280" text-anchor="middle">The sandwiches are independent: four burners finish at t = 4 what one burner finishes at t = 16.</text>
</svg>

Code is the same. Parallelization pays off when the pieces of work are **independent** — each can run without waiting on the results of another. When a job splits cleanly into fully independent tasks with no coordination between them, it's called **embarrassingly parallel** — the easiest, highest-payoff kind of work to parallelize.

A quick test, in kitchen terms: if you could hand each task to a different cook and never have them talk to each other, it will parallelize. Your extraction job fits perfectly — every filing is its own self-contained task.

{: .note }
> Parallelization doesn't make a single task faster — one grilled cheese still takes its four steps. It makes *many* tasks finish sooner by running them at the same time. If your bottleneck is one slow step, parallelizing won't help; you need a faster step.

Let's run through some examples together and discuss what types of tasks are parallelizable (or useful to parallelize):

<details markdown="1">
<summary>Example 1</summary>

You're given an array of numbers, and you're asked to compute the sum of the numbers in the array:

<div style="text-align:center;font-size:1.15em;margin:0.75rem 0">∑<sub>x ∈ array</sub> x</div>

Is parallelizing possible and/or worthwhile?

What if we want to compute the sum of some complicated function of each number (see below)?

<div style="text-align:center;font-size:1.15em;margin:0.75rem 0">∑<sub>x ∈ array</sub> f(x)</div>

</details>

<details markdown="1">
<summary>Example 2</summary>

You have a dataset A where rows are meant to have a unique key. You want to merge dataset B onto A, but without the merge creating new rows. A standard way to avoid that is to check that A's rows are unique. Can this be parallelized?

</details>

<details markdown="1">
<summary>Example 3</summary>

You're scraping a website to compile a dataset. After scraping each page, you want to write some variables you found on the page to a common `.csv` that will store the results from all the webpages you've scraped. Can this be parallelized?

</details>

<label class="quest-check"><input type="checkbox" data-room="d4-parallelization" data-key="main"> I can explain what parallelization is, when it can be used, and when it helps</label>

<details markdown="1">
<summary>🔮 How to cast your progress — click to reveal</summary>

Every quest you check reveals a **🔮 Cast to the leaderboard** button with a one-line `./cast` spell. To record it:

1. SSH to the Yens — `ssh SUNetID@yen.stanford.edu`
2. `cd` to your repo — `cd ~/gsb-research-computing-ai-skills`
3. Paste the `./cast …` spell from the quest and run it.

</details>

---

## Ways to Parallelize

Let's make this concrete with the job you ran yesterday: processing SEC filings. Each filing is a sandwich: fetch it, send it to the API, save the fields that come back — those steps run in order, and no filing needs anything from another. So 100 filings are 100 independent sandwiches. There's more than one way to spread them out: give one job more cores, run more jobs, or do both.

Recall yesterday's script. It ran as **one job on one core** — a `for` loop walking the filings in sequence:

```python
for filing in filings:          # 100 filings in the list
    result = extract(filing)     # one core does this, start to finish
    save(result)
# the loop can't start filing 2 until filing 1 is done
```

<svg viewBox="0 0 600 178" role="img" aria-labelledby="jc1-title jc1-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:598px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="jc1-title">One job, one core</title>
  <desc id="jc1-desc">A single Slurm job box holds one CPU and eight filings in a row. The CPU moves from filing to filing one at a time.</desc>
  <rect x="6" y="6" width="588" height="136" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="22" y="25" font-size="12" font-weight="700" fill="#8a93a3">Job</text>
  <rect x="22"  y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="52"  y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 1</text>
  <rect x="92"  y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="122" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 2</text>
  <rect x="162" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="192" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 3</text>
  <rect x="232" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="262" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 4</text>
  <rect x="302" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="332" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 5</text>
  <rect x="372" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="402" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 6</text>
  <rect x="442" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="472" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 7</text>
  <rect x="512" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="542" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 8</text>
  <g>
    <path d="M45,75 L59,75 L52,86 Z" fill="#0072B2"/>
    <circle cx="52" cy="58" r="18" fill="#0072B2"><animate attributeName="r" values="18;20;18" dur="1s" repeatCount="indefinite"/></circle>
    <text x="52" y="62" font-size="10" font-weight="700" fill="#ffffff" text-anchor="middle">CPU</text>
    <animateTransform attributeName="transform" type="translate"
      values="0,0;0,0;70,0;70,0;140,0;140,0;210,0;210,0;280,0;280,0;350,0;350,0;420,0;420,0;490,0;490,0;0,0"
      keyTimes="0;0.07;0.12;0.19;0.24;0.31;0.36;0.43;0.48;0.55;0.60;0.67;0.72;0.79;0.84;0.91;1"
      dur="14s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <text x="300" y="164" font-size="12.5" fill="#6a7280" text-anchor="middle">One job, one core — the filings are processed one after another. ≈ 8 × 5s = 40s.</text>
</svg>

If one filing takes 5 seconds, 100 filings take ~500 seconds — and the whole time your script is using exactly one core. A Yen node has dozens more you could have asked for.

{: .demo }
> Watch as we run this baseline and each of the three approaches below on the Yens — **20 filings every time**, so the only thing that changes is how the work is spread. (The diagrams use 8 filings to stay legible; the live runs do 20.) This first one is the baseline: **1 job, 1 core, 20 filings, 20 API calls.**
>
> After each run, `watch sacct -X -j JOBID --format=JobID,State,Elapsed,TotalCPU,ReqCPUS,MaxRSS` shows what it cost: `Elapsed` is the wall-clock time, `TotalCPU` against `ReqCPUS` shows how busy the reserved cores actually stayed, and `MaxRSS` is the peak memory — the same field you compared against your estimate on [Day 3](../../day3/capstone/).

**Approach 1: One job, many cores — parallelize _within_ a job.** Ask the same job for several cores (on the Yens, set `#SBATCH --cpus-per-task` in your `.slurm` script) and split the filings across them in your code. But you're capped at the cores on a single machine:

<svg viewBox="0 0 600 178" role="img" aria-labelledby="jc2-title jc2-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:598px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="jc2-title">One job, many cores</title>
  <desc id="jc2-desc">A single Slurm job box holds two CPUs and eight filings. The two CPUs work different filings at the same time, sweeping the row in four waves.</desc>
  <rect x="6" y="6" width="588" height="136" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="22" y="25" font-size="12" font-weight="700" fill="#8a93a3">Job</text>
  <rect x="22"  y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="52"  y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 1</text>
  <rect x="92"  y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="122" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 2</text>
  <rect x="162" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="192" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 3</text>
  <rect x="232" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="262" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 4</text>
  <rect x="302" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="332" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 5</text>
  <rect x="372" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="402" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 6</text>
  <rect x="442" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="472" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 7</text>
  <rect x="512" y="86" width="60" height="48" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="542" y="114" font-size="11" fill="#2c3e50" text-anchor="middle">filing 8</text>
  <g>
    <path d="M45,75 L59,75 L52,86 Z" fill="#0072B2"/>
    <circle cx="52" cy="58" r="18" fill="#0072B2"><animate attributeName="r" values="18;20;18" dur="1s" repeatCount="indefinite"/></circle>
    <text x="52" y="61" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 1</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;140,0;140,0;280,0;280,0;420,0;420,0;0,0" keyTimes="0;0.14;0.20;0.34;0.40;0.54;0.60;0.74;1" dur="12s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <g>
    <path d="M115,75 L129,75 L122,86 Z" fill="#E69F00"/>
    <circle cx="122" cy="58" r="18" fill="#E69F00"><animate attributeName="r" values="18;20;18" dur="1s" repeatCount="indefinite"/></circle>
    <text x="122" y="61" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 2</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;140,0;140,0;280,0;280,0;420,0;420,0;0,0" keyTimes="0;0.14;0.20;0.34;0.40;0.54;0.60;0.74;1" dur="12s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <text x="300" y="164" font-size="12.5" fill="#6a7280" text-anchor="middle">One job, two cores — they split the filings and finish in waves. ≈ 4 × 5s = 20s.</text>
</svg>

Two cores clear the eight filings in four waves — ≈ 4 × 5s = 20s of wall-clock, versus ~40s one at a time. Same total work, spread across two cores.

{: .tip }
> **Ask Claude Code for help with parallelizing within a job.** Get it to split the filings across the cores for you: describe your loop and say how many cores you asked for. Read what it gives you before you run it — check that the work really is independent.

{: .demo }
> Let's run an example like this on the Yens and see how it performs — the same 20 filings as the baseline, now split across the cores of a single job: **1 job, 2 cores, 20 filings, 20 API calls.**

**Approach 2: Many jobs, one core each — parallelize _across_ jobs.** Submit a **job array**: the scheduler launches many near-identical jobs at once, each an independent task on (possibly) a different node, each working its own slice of the filings. This scales past a single machine, and because every task stands alone, a failure costs you only that task:

<svg viewBox="0 0 600 300" role="img" aria-labelledby="jc3-title jc3-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:598px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="jc3-title">Many jobs, one core each</title>
  <desc id="jc3-desc">Two separate Slurm job boxes stacked vertically, each with its own CPU. The first job's CPU processes filings 1 to 4; the second job's CPU processes filings 5 to 8, both at the same time.</desc>
  <rect x="6" y="6" width="588" height="124" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="22" y="24" font-size="12" font-weight="700" fill="#8a93a3">Job 1</text>
  <rect x="40"  y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="75"  y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 1</text>
  <rect x="190" y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="225" y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 2</text>
  <rect x="340" y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="375" y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 3</text>
  <rect x="490" y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="525" y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 4</text>
  <g>
    <path d="M68,70 L82,70 L75,80 Z" fill="#0072B2"/>
    <circle cx="75" cy="54" r="16" fill="#0072B2"><animate attributeName="r" values="16;18;16" dur="1s" repeatCount="indefinite"/></circle>
    <text x="75" y="57" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 1</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;150,0;150,0;300,0;300,0;450,0;450,0;0,0" keyTimes="0;0.14;0.20;0.34;0.40;0.54;0.60;0.74;1" dur="12s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <rect x="6" y="146" width="588" height="124" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="22" y="164" font-size="12" font-weight="700" fill="#8a93a3">Job 2</text>
  <rect x="40"  y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="75"  y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 5</text>
  <rect x="190" y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="225" y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 6</text>
  <rect x="340" y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="375" y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 7</text>
  <rect x="490" y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="525" y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 8</text>
  <g>
    <path d="M68,210 L82,210 L75,220 Z" fill="#E69F00"/>
    <circle cx="75" cy="194" r="16" fill="#E69F00"><animate attributeName="r" values="16;18;16" dur="1s" repeatCount="indefinite"/></circle>
    <text x="75" y="197" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 2</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;150,0;150,0;300,0;300,0;450,0;450,0;0,0" keyTimes="0;0.14;0.20;0.34;0.40;0.54;0.60;0.74;1" dur="12s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <text x="300" y="290" font-size="12.5" fill="#6a7280" text-anchor="middle">Two jobs, one core each — each job works its own slice, in parallel. ≈ 4 × 5s = 20s.</text>
</svg>

We'll cover job arrays in detail on the [next page](../slurm-arrays/).

{: .note }
> **The tasks are identical — so you have to tell them apart.** Every task in an array runs the same script, which means nothing decides on its own which filing each one takes. That mapping is yours to write.

{: .demo }
> Let's run an example like this on the Yens and see how it performs — the same 20 filings again, this time split across independent jobs: **2 jobs, 1 core each, 10 filings apiece, 20 API calls.**

**Approach 3: Many jobs, many cores — do both.** Nothing stops an array task from itself requesting several cores. Reach for this when one alone isn't enough: many jobs to spread across nodes, several cores inside each to chew through a big slice:

<svg viewBox="0 0 600 300" role="img" aria-labelledby="jc4-title jc4-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:598px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="jc4-title">Many jobs, many cores</title>
  <desc id="jc4-desc">Two stacked Slurm job boxes, each holding two CPUs and four filings. In each job the two CPUs split the four filings two-and-two, and the two jobs run at the same time.</desc>
  <rect x="6" y="6" width="588" height="124" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="22" y="24" font-size="12" font-weight="700" fill="#8a93a3">Job 1</text>
  <rect x="40"  y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="75"  y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 1</text>
  <rect x="190" y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="225" y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 2</text>
  <rect x="340" y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="375" y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 3</text>
  <rect x="490" y="80" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="525" y="106" font-size="12" fill="#2c3e50" text-anchor="middle">filing 4</text>
  <g>
    <path d="M68,70 L82,70 L75,80 Z" fill="#0072B2"/>
    <circle cx="75" cy="54" r="16" fill="#0072B2"><animate attributeName="r" values="16;18;16" dur="1s" repeatCount="indefinite"/></circle>
    <text x="75" y="57" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 1</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;300,0;300,0;0,0" keyTimes="0;0.30;0.42;0.72;1" dur="12s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <g>
    <path d="M218,70 L232,70 L225,80 Z" fill="#E69F00"/>
    <circle cx="225" cy="54" r="16" fill="#E69F00"><animate attributeName="r" values="16;18;16" dur="1s" repeatCount="indefinite"/></circle>
    <text x="225" y="57" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 2</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;300,0;300,0;0,0" keyTimes="0;0.30;0.42;0.72;1" dur="12s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <rect x="6" y="146" width="588" height="124" rx="12" fill="#f7f9fd" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="22" y="164" font-size="12" font-weight="700" fill="#8a93a3">Job 2</text>
  <rect x="40"  y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="75"  y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 5</text>
  <rect x="190" y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="225" y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 6</text>
  <rect x="340" y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="375" y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 7</text>
  <rect x="490" y="220" width="70" height="44" rx="9" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="525" y="246" font-size="12" fill="#2c3e50" text-anchor="middle">filing 8</text>
  <g>
    <path d="M68,210 L82,210 L75,220 Z" fill="#009E73"/>
    <circle cx="75" cy="194" r="16" fill="#009E73"><animate attributeName="r" values="16;18;16" dur="1s" repeatCount="indefinite"/></circle>
    <text x="75" y="197" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 3</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;300,0;300,0;0,0" keyTimes="0;0.30;0.42;0.72;1" dur="12s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <g>
    <path d="M218,210 L232,210 L225,220 Z" fill="#D55E00"/>
    <circle cx="225" cy="194" r="16" fill="#D55E00"><animate attributeName="r" values="16;18;16" dur="1s" repeatCount="indefinite"/></circle>
    <text x="225" y="197" font-size="8.5" font-weight="700" fill="#ffffff" text-anchor="middle">CPU 4</text>
    <animateTransform attributeName="transform" type="translate" values="0,0;0,0;300,0;300,0;0,0" keyTimes="0;0.30;0.42;0.72;1" dur="12s" repeatCount="indefinite" calcMode="linear"/>
  </g>
  <text x="300" y="290" font-size="12.5" fill="#6a7280" text-anchor="middle">Two jobs, two cores each — both at once. ≈ 2 × 5s = 10s.</text>
</svg>

{: .demo }
> Let's run an example like this on the Yens and see how it performs — the same 20 filings once more, now spread across both jobs and cores: **2 jobs, 2 cores each, 10 filings apiece, 20 API calls.**

Putting the four possibilities side by side:

|  | **One core per job** | **Many cores per job** |
|---|---|---|
| **One job** | Day 3's baseline — a `for` loop, one filing at a time. No speedup. | **Approach 1.** `--cpus-per-task=N`, then split the filings across the cores in your code. Capped at one node. |
| **Many jobs** | **Approach 2.** A job array. Scales past one node, and one task failing costs you only that task. The number of tasks you can queue is capped. | **Approach 3.** A job array whose tasks each ask for several cores. The most throughput, but the largest request — and the longer the queue wait. |

---

## More Filings Than Cores (and Vice Versa)

The illustrations above show a tidy few-filings-per-core picture. In practice the ratios vary, and both directions come up constantly.

**More filings than cores — the usual case.** Say you have 100 filings but only 8 cores. The cores work in *waves*: the first 8 filings run at once, and the moment a core finishes it picks up the next filing in line, until all 100 are done. The total time is roughly the number of waves times the per-filing time — about ⌈100 ÷ 8⌉ = 13 waves × 5s ≈ 65s, versus ~500s in serial. You don't manage the waves yourself: within a job your code hands out the next filing; across array jobs, the scheduler does.

**More cores than filings.** Say you have 5 filings but the same 8 cores. Only 5 cores can do anything — a single filing can't be split across cores — so the other 3 sit idle. Cores beyond the number of independent tasks buy you nothing, and requesting more than you'll use can mean a longer wait in the queue for resources you never touch. Once the job starts, Slurm holds those cores for you whether you use them or not — so they sit idle in your job instead of running someone else's. The Yens are shared; ask for what you'll actually use.

---

<label class="quest-check"><input type="checkbox" data-room="d4-parallelization" data-key="approaches"> I can explain a few ways to parallelize — more cores within one job, more jobs, or both</label>

---

{: .tip }
> **Hitting a wall on resources in the future? Ask us.** If a job is too slow, or you're bumping up against what you can reasonably request, the DARC team is happy to look at your code with you.

## What You Learned

- You can explain the difference between running tasks sequentially on one core and in parallel across many
- You can tell whether a workload is **independent** enough to parallelize
- You can explain a few ways to parallelize — more cores **within** one job, more **jobs**, or both — and name the limit each one runs into
- You understand that parallelization speeds up *many* tasks, not a single slow one
