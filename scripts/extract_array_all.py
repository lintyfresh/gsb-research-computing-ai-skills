import os

# Same pin as the other extraction scripts, and it matters most here: 496 tasks,
# up to 100 running at once, each otherwise free to grab a thread per core on a
# shared node. Must be set before pandas is imported.
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("OMP_NUM_THREADS", "1")

import json
import sys
import time
from pathlib import Path
from typing import List

import requests
import pandas as pd
from openai import OpenAI
from pydantic import BaseModel
from dotenv import load_dotenv

CSV_PATH = "data/aws_links.csv"
RESULTS_DIR = Path("results")

# 992 filings / 2 per task = 496 tasks, just under the 512 array cap.
FILINGS_PER_TASK = 2

# Spacing between API calls inside one task. Does not prevent the opening burst
# when many tasks start at once -- only a concurrency cap (--array=...%N) does
# that -- but it costs nothing and smooths the calls a task makes in sequence.
PAUSE_SECONDS = 2


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

task_id = int(sys.argv[1])  # 1 ... 496

# Same filter chain as the other scripts, so positions line up with results
# already on disk: drop blank rows, keep only .txt filings. No [:100] truncation
# here -- this run covers all 992.
urls = pd.read_csv(CSV_PATH)["urls"].dropna().tolist()
filings = [u for u in urls if u.endswith(".txt")]

# This task's contiguous slice. Tasks count from 1, the list from 0.
start = (task_id - 1) * FILINGS_PER_TASK
chunk = filings[start:start + FILINGS_PER_TASK]

if not chunk:
    print(f"[task {task_id}] no filings in range — nothing to do")
    sys.exit(0)

load_dotenv()
client = OpenAI(
    base_url="https://aiapi-prod.stanford.edu/v1",
    api_key=os.getenv("STANFORD_API_KEY"),
)

failures = 0

for i, filing_url in enumerate(chunk):
    if i > 0:
        time.sleep(PAUSE_SECONDS)

    filename = filing_url.split("/")[-1]
    output_path = RESULTS_DIR / filename.replace(".txt", ".json")

    # Already done? Stop before spending an API call. This is what makes the
    # array safe to resubmit -- finished filings cost nothing.
    if output_path.exists():
        print(f"{output_path} already exists — skipping")
        continue

    print(f"[task {task_id}] Processing: {filename}")

    # One filing failing must not cost its partner in the same task.
    try:
        filing_text = requests.get(filing_url).text

        api_response = client.chat.completions.create(
            model="gemini-2.5-flash",
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": filing_text},
            ],
        )

        result = Form3Filing.model_validate_json(
            api_response.choices[0].message.content
        )

        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            json.dump(result.model_dump(), f, indent=2)

        print(f"  → saved {output_path}")
    except Exception as exc:
        failures += 1
        print(f"  ✗ {filename} failed: {type(exc).__name__}: {exc}", file=sys.stderr)

# Exit non-zero if anything failed, so sacct State stays meaningful -- a task
# that swallowed both its errors should not report COMPLETED.
sys.exit(1 if failures else 0)
