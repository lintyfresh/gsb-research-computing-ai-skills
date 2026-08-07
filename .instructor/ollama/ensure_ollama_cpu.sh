#!/bin/bash
# Stand up the CPU contrast server for Day 4 and print its URL.
#
#     bash .instructor/ollama/ensure_ollama_cpu.sh
#
# Same container, same model, same queries as the GPU server — answers just
# arrive a word at a time. That contrast is the point of running it.
#
# This is a thin wrapper around ensure_ollama_server.sh: it sets the four things
# that make the job a CPU job and hands off. All the logic, and the reasoning
# behind every default, lives in that script; read it there, not here.
#
# Its companion is ensure_ollama_gpu.sh. Run both, in either order, to have both
# servers up at once — they are independent jobs and neither waits on the other.
# Each prints its own URL, and they are different URLs.
#
# Environment overrides still pass through, e.g.:
#
#     CPUS=16 bash .instructor/ollama/ensure_ollama_cpu.sh
#
# Co-authored by Claude (Anthropic).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The separate scratch tree is not optional. ollama.sh keeps host.txt, port.txt
# and the model weights under a single ${SCRATCH_BASE}/ollama, so two servers
# sharing one tree would overwrite each other's coordinates and you would lose
# track of whichever started first. The cost is that this tree re-downloads the
# ~2 GB of weights.
#
# Derived from SCRATCH_BASE rather than hardcoded so that an inherited value is
# still visible to ensure_ollama_server.sh's superseded-path warning — the
# /scratch/shared/$USER trap it guards against should fire here too, not be
# silently papered over.
export SCRATCH_BASE="${SCRATCH_BASE:-/scratch/users/$USER}/cpu"

# A distinct job name keeps this server's "is one already on its way?" check
# from matching the GPU job, and vice versa.
export JOB_NAME="${JOB_NAME:-ollama-cpu}"

# GPUS=0 also suppresses the --constraint and --reservation flags in
# ensure_ollama_server.sh: both select GPU nodes, so a CPU job carrying either
# would sit in the queue forever.
export PARTITION="${PARTITION:-normal}"
export GPUS="${GPUS:-0}"

exec bash "${HERE}/ensure_ollama_server.sh"
