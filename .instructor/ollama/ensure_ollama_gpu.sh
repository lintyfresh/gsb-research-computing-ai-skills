#!/bin/bash
# Stand up the GPU Ollama server for Day 4 and print its URL.
#
#     bash .instructor/ollama/ensure_ollama_gpu.sh
#
# This is a thin wrapper around ensure_ollama_server.sh — it just pins the two
# settings that make this "the GPU one" and hands off. All the logic, and the
# reasoning behind every default (walltime, cores, health probe, reservation),
# lives in that script; read it there, not here.
#
# Its companion is ensure_ollama_cpu.sh. Run both, in either order, to have the
# GPU and CPU servers up at once for the speed contrast — they are independent
# jobs and neither waits on the other.
#
# Environment overrides still pass through, e.g.:
#
#     WALLTIME=15:00:00 bash .instructor/ollama/ensure_ollama_gpu.sh
#     RESERVATION= bash .instructor/ollama/ensure_ollama_gpu.sh   # open queue
#
# Co-authored by Claude (Anthropic).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set explicitly rather than leaning on ensure_ollama_server.sh's defaults, so
# this file says what it does on its face and keeps saying it if those defaults
# ever move. `:-` throughout, so an override on the command line still wins.
export PARTITION="${PARTITION:-gpu}"
export GPUS="${GPUS:-1}"

exec bash "${HERE}/ensure_ollama_server.sh"
