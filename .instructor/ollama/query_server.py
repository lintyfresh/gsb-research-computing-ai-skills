#!/usr/bin/env python3
"""Query the shared Ollama server exactly as students do on running-llms.md.

Ready to run on the Yens once a server is up:

    python .instructor/ollama/query_server.py
    python .instructor/ollama/query_server.py "What is an SEC Form 3 filing?"
    python .instructor/ollama/query_server.py --url http://yen-gpu1:41234/v1 "..."

With no --url it reads the coordinates that ollama.sh writes under
$SCRATCH_BASE/ollama/, so it finds your own server without being told. Those
files are mode 700, which is why students get the URL read out to them instead.

Needs the `openai` package — the same one Day 2 installs. If the import fails,
activate the course venv first.

Two uses:
  1. Check the server actually answers before class, not just that it binds a
     port. A bound port is not a working server: start_ollama_server.sh pulls
     the model *after* the server comes up, so there is a window in which GET /
     says "Ollama is running" while every real query returns model-not-found.
  2. Time GPU against CPU. Point it at each server in turn with --url; the
     elapsed line is the measurement the GPU-vs-CPU demo needs.

Co-authored by Claude (Anthropic).
"""

import argparse
import os
import pathlib
import sys
import time

from openai import OpenAI

DEFAULT_QUERY = "Who is the president of the USA, and what is their background?"
DEFAULT_MODEL = "llama3.2:1b"

# Cap the answer length. "In one sentence" is a request the model may ignore,
# and wall-clock here is almost entirely tokens generated — so without a cap a
# chatty answer can run for minutes on CPU, which is fatal for a demo that has
# to hold a room's attention.
#
# The cap costs nothing in rigour: it bounds wall-clock without touching the
# tokens-per-second figure the GPU/CPU comparison actually rests on. Both sides
# generate the same number of tokens; only the time to do so differs, which is
# the whole point.
DEFAULT_MAX_TOKENS = 100


def url_from_scratch() -> str:
    """Read the URL from the host/port files ollama.sh leaves in scratch."""
    scratch_base = os.environ.get("SCRATCH_BASE", f"/scratch/users/{os.environ['USER']}")
    coord_dir = pathlib.Path(scratch_base) / "ollama"
    host_file, port_file = coord_dir / "host.txt", coord_dir / "port.txt"

    if not (host_file.is_file() and port_file.is_file()):
        sys.exit(
            f"No server coordinates in {coord_dir}. Either start one with\n"
            f"  bash .instructor/ollama/ensure_ollama_gpu.sh   (or ensure_ollama_cpu.sh)\n"
            f"or pass the URL explicitly with --url."
        )

    # The coordinate files hold only host and port, so the OpenAI-compatible
    # path is added here. This is the one place that happens: a URL given with
    # --url is passed through untouched.
    return f"http://{host_file.read_text().strip()}:{port_file.read_text().strip()}/v1"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("query", nargs="?", default=DEFAULT_QUERY)
    parser.add_argument(
        "--url",
        help="full base URL including /v1, e.g. http://yen-gpu1:41234/v1 — "
             "the Python form the server banner prints, used as given",
    )
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=DEFAULT_MAX_TOKENS,
        help=f"cap the answer length (default {DEFAULT_MAX_TOKENS}); 0 for no cap",
    )
    args = parser.parse_args()

    base_url = args.url or url_from_scratch()
    print(f"Server:  {base_url}")
    print(f"Model:   {args.model}")
    print(f"Query:   {args.query}\n")

    client = OpenAI(
        base_url=base_url,   # used exactly as given; see --url below
        api_key="ollama",    # ignored, but the client requires a value
    )

    started = time.perf_counter()
    response = client.chat.completions.create(
        model=args.model,
        messages=[{"role": "user", "content": args.query}],
        max_tokens=args.max_tokens or None,   # 0 means "no cap"
    )
    elapsed = time.perf_counter() - started

    print(response.choices[0].message.content)

    # Token count makes the timing comparable across queries of different
    # lengths — the GPU/CPU contrast is about tokens per second, not wall clock.
    completion_tokens = getattr(response.usage, "completion_tokens", None)
    rate = f", {completion_tokens / elapsed:.1f} tok/s" if completion_tokens else ""
    print(f"\n[{elapsed:.1f}s{rate}]")


if __name__ == "__main__":
    main()
