"""Extract structured fields from one SEC Form 3 filing, fetched by URL.

Same conventions as scripts/extract_form_3_batch.py — the S3 URLs from
data/aws_links.csv, requests.get to fetch, the same schema and prompt — but one
filing per invocation instead of a for loop. (The model differs for now: see the
note at the call site.) That is what lets the demo
scripts fan the work out, whether across cores (xargs -P) or across array tasks.

    python .instructor/parallelization_demos/extract_one_url.py <filing_url> <output_path>
"""

import os
import sys
import json
from pathlib import Path
from typing import List

import requests
from openai import OpenAI
from pydantic import BaseModel
from dotenv import load_dotenv


class Form3Filing(BaseModel):
    insider_name: str
    insider_role: List[str]
    company_name: str
    company_cik: str
    filing_date: str


SYSTEM_PROMPT = """
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


def main():
    filing_url = sys.argv[1]
    output_path = Path(sys.argv[2])

    # Already processed? Skip it, so a demo is cheap to re-run and a partial
    # failure only costs the filings that actually failed.
    if output_path.exists():
        print(f"{output_path} already exists — skipping")
        return

    load_dotenv()
    client = OpenAI(
        base_url="https://aiapi-prod.stanford.edu/v1",
        api_key=os.getenv("STANFORD_API_KEY"),
    )

    filing_text = requests.get(filing_url).text

    response = client.chat.completions.create(
        # Temporary: this key can't reach gpt-4o-mini, and the gateway's
        # gemini-2.5-flash-lite deployment is in cooldown (429, "no deployments
        # available"). flash is the same family and is serving.
        model="gemini-2.5-flash",
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": filing_text},
        ],
    )

    result = Form3Filing.model_validate_json(response.choices[0].message.content)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result.model_dump(), indent=2))

    print(f"Saved {output_path}")


if __name__ == "__main__":
    main()
