import os

# Same pin as the serial batch script, and it matters far more here: an array
# runs 100 of these at once, each otherwise free to grab a thread per core on a
# shared node. Must be set before pandas is imported.
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("OMP_NUM_THREADS", "1")

import json
import sys
from pathlib import Path
from typing import List

import requests
import pandas as pd
from openai import OpenAI
from pydantic import BaseModel
from dotenv import load_dotenv

CSV_PATH = "data/aws_links.csv"
RESULTS_DIR = Path("results")
NUM_FILINGS = 100


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

task_id = int(sys.argv[1])  # handed over by the array script: 1, 2, ... 100

# Same filter chain as the serial script, so positions line up with the results
# already on disk: drop blank rows, keep only .txt filings (the first row is the
# S3 folder, and one row further down has an empty url), then take the first 100.
urls = pd.read_csv(CSV_PATH)["urls"].dropna().tolist()
filings = [u for u in urls if u.endswith(".txt")][:NUM_FILINGS]

filing_url = filings[task_id - 1]  # tasks count from 1, the list from 0
filename = filing_url.split("/")[-1]
output_path = RESULTS_DIR / filename.replace(".txt", ".json")

# Already done? Stop before spending an API call. This is what makes the array
# safe to resubmit after a partial failure -- finished filings cost nothing.
if output_path.exists():
    print(f"{output_path} already exists — skipping")
    sys.exit(0)

print(f"[task {task_id}] Processing: {filename}")

load_dotenv()
client = OpenAI(
    base_url="https://aiapi-prod.stanford.edu/v1",
    api_key=os.getenv("STANFORD_API_KEY"),
)

filing_text = requests.get(filing_url).text

api_response = client.chat.completions.create(
    model="gemini-2.5-flash",
    response_format={"type": "json_object"},
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": filing_text},
    ],
)

result = Form3Filing.model_validate_json(api_response.choices[0].message.content)

output_path.parent.mkdir(parents=True, exist_ok=True)
with open(output_path, "w") as f:
    json.dump(result.model_dump(), f, indent=2)

print(f"  → saved {output_path}")
