#!/bin/bash
# Start the shared Ollama server for the Day 4 demo, and make sure the model is
# cached. Normally run this on a GPU node — grab one first with, e.g.:
#
#     RESERVATION=class_day4   # the Day 4 teaching reservation (H200 capacity)
#     srun -p gpu -G 1 --reservation="$RESERVATION" -n 1 -t 4:00:00 --pty /bin/bash
#
# Drop --reservation outside the reserved window — the name only resolves while
# the reservation is active, and srun refuses the allocation otherwise. No
# -C "GPU_MODEL:..." here on purpose: the reservation already picks the node, and
# a card-model filter on top can only exclude it. Add one when you are on the
# open queue instead.
#
# It also runs without a GPU, which is worth demonstrating: same server, same
# queries, answers arriving a word at a time. The script warns and continues.
#
# then, ideally inside `screen` so it survives a dropped connection:
#
#     screen -S ollama
#     bash .instructor/ollama/start_ollama_server.sh
#
# The script is idempotent: the container image and the model weights are only
# downloaded if they are missing, so a re-run after a scratch purge costs a
# slower start rather than manual repair.
#
# Follows https://rcpedia.stanford.edu/blog/2025/05/12/running-ollama-on-stanford-computing-clusters/
# with two deliberate deviations: per-user scratch is /scratch/users/ (the post
# still shows the old /scratch/shared/<user>/), and we serve Meta's open-weight
# Llama 3.2 rather than the post's deepseek-r1:7b — Llama is not a reasoning
# model, so it doesn't wrap replies in <think> blocks that break strict JSON
# parsing downstream.

set -euo pipefail

MODEL="${MODEL:-llama3.2:1b}"
SCRATCH_BASE="${SCRATCH_BASE:-/scratch/users/$USER}"
HELPER_DIR="${HELPER_DIR:-$HOME/ollama_helper}"   # holds ollama.sh and ollama.sif
LOG="${SCRATCH_BASE}/ollama/server.log"

export SCRATCH_BASE

# --- where are we running? -------------------------------------------------
# CPU is supported deliberately: llama3.2:1b is small enough to answer on CPU,
# just slowly, which is worth showing. But a CPU node is almost never what you
# want by accident, so say so loudly. (nvidia-smi can exist on a node with no
# GPU allocated to you, hence -L rather than a bare command -v.)
if nvidia-smi -L >/dev/null 2>&1 && [ -n "$(nvidia-smi -L 2>/dev/null)" ]; then
  echo "GPU detected:"
  nvidia-smi -L | sed 's/^/  /'
else
  cat >&2 <<'WARN'

  ⚠  No GPU visible — the model will run on CPU.

     Expect seconds per token rather than tokens per second, and expect
     Apptainer to print "Could not find any nv files on this host!" as it
     starts: that is the GPU passthrough finding nothing, not an error.

     For the real demo, get a GPU node first — see the header of this script.

WARN
fi

# --- one-time setup, skipped when already present --------------------------
if [ ! -d "$HELPER_DIR" ]; then
  echo "Cloning ollama_helper into $HELPER_DIR"
  git clone https://github.com/gsbdarc/ollama_helper.git "$HELPER_DIR"
fi
cd "$HELPER_DIR"

ml apptainer

if [ ! -f ollama.sif ]; then
  echo "Pulling the Ollama container image (slow the first time)"
  apptainer pull ollama.sif docker://ollama/ollama
fi

mkdir -p "${SCRATCH_BASE}/ollama"

# defines the `ollama` wrapper; it exports the function so subshells inherit it
source ollama.sh

# Keep the model resident once loaded, rather than Ollama's default of unloading
# after 5 minutes idle. Two reasons, and the second is the subtle one:
#
#   1. A server warmed before class would otherwise go cold during the walk-in,
#      and the first student to query pays the load again.
#   2. `keep_alive` is an Ollama extension with no place in the OpenAI schema, so
#      requests arriving at /v1/chat/completions — which is every request the
#      course makes — cannot carry it and fall back to the default. Pinning it
#      per-request is therefore not enough; only changing the default is, which
#      is what OLLAMA_KEEP_ALIVE does.
#
# APPTAINERENV_ prefix because the server runs inside the container: Apptainer
# strips the prefix and sets OLLAMA_KEEP_ALIVE within. Patching ollama.sh's
# --env list would work too, but that file is DARC's and we would rather not
# carry a local fork of it.
export APPTAINERENV_OLLAMA_KEEP_ALIVE="${OLLAMA_KEEP_ALIVE:--1}"

# --- start the server ------------------------------------------------------
# Redirect to a log rather than the terminal: `ollama serve` otherwise blocks,
# and a file keeps a record of what the class actually sent if a query needs
# debugging afterwards.
echo "Starting the server — logging to $LOG"
ollama serve > "$LOG" 2>&1 &
SERVER_PID=$!
trap 'echo; echo "Stopping the server."; kill "$SERVER_PID" 2>/dev/null || true' EXIT

# ollama.sh picks a port and records the coordinates *before* handing off to the
# container, so these files appear almost immediately — their existence says
# nothing about whether anything is listening yet.
for _ in $(seq 10); do
  [ -s "${SCRATCH_BASE}/ollama/port.txt" ] && break
  sleep 1
done
if [ ! -s "${SCRATCH_BASE}/ollama/port.txt" ]; then
  echo "ERROR: the server never recorded a port. See $LOG." >&2
  exit 1
fi

HOST=$(<"${SCRATCH_BASE}/ollama/host.txt")
PORT=$(<"${SCRATCH_BASE}/ollama/port.txt")

# So poll the endpoint itself. Ollama answers "Ollama is running" on / once it
# has bound. Five minutes is generous, but container start on a cold cache and
# a CPU-only load are both slow.
echo -n "Waiting for http://${HOST}:${PORT} to answer"
READY=""
for _ in $(seq 150); do
  if curl -sf --max-time 2 "http://${HOST}:${PORT}/" >/dev/null 2>&1; then
    READY=1; break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo; echo "ERROR: the server exited during startup. Last lines of $LOG:" >&2
    tail -20 "$LOG" >&2
    exit 1
  fi
  echo -n "."
  sleep 2
done
echo

if [ -z "$READY" ]; then
  echo "ERROR: the server did not answer within five minutes. See $LOG." >&2
  exit 1
fi

# --- cache the model -------------------------------------------------------
# A no-op once the weights are in ${SCRATCH_BASE}/ollama/models.
echo "Ensuring $MODEL is available"
ollama pull "$MODEL"

# --- pin the thread count --------------------------------------------------
# Not a tuning nicety — without this the CPU server is unusable. llama.cpp sizes
# its thread pool from the machine's CPU count and ignores the cgroup Slurm
# confines the job to: on yen12 it chose `n_threads = 128 ... / 256` while
# holding an 8-core allocation. It busy-waits at its synchronisation barriers,
# so 16x oversubscription costs far more than idle threads would suggest — a
# 100-token answer had still not returned after two and a half minutes. With the
# pin, the same query took 7.7s (13 tok/s, llama3.2:1b, verified 2026-08-02).
#
# It has to be baked into the model rather than sent with a request, and the
# failure is silent. Passing num_thread with the preload does take effect, and
# is then undone by the first real query: /v1/chat/completions carries no Ollama
# options, so Ollama reads the resident runner as having the wrong option set
# and reloads it with the defaults restored. The server log shows n_threads
# going 128 -> 8 -> 128 across preload then query. A baked parameter is not
# overridable that way, so it survives.
#
# `ollama create` taking $MODEL as its own FROM keeps the name the class is
# given, so nothing downstream needs to know this happened. The container has
# ${SCRATCH_BASE}/ollama mounted at /root, hence the two paths for one file.
#
# SLURM_CPUS_PER_TASK is what we asked for; nproc honours CPU affinity and so
# covers running outside Slurm. Threads are matched to cores rather than logical
# CPUs: llama.cpp generally loses throughput once threads exceed cores.
THREADS="${OLLAMA_THREADS:-${SLURM_CPUS_PER_TASK:-$(nproc)}}"
echo "Pinning $MODEL to $THREADS threads"
printf 'FROM %s\nPARAMETER num_thread %s\n' "$MODEL" "$THREADS" \
  > "${SCRATCH_BASE}/ollama/Modelfile"
ollama create "$MODEL" -f /root/Modelfile

# --- load it into memory ---------------------------------------------------
# Caching the weights on disk is not the same as having them in memory, and the
# gap between the two is minutes on CPU. Ollama loads lazily on first query, so
# without this the cost lands on whoever queries first — in class, twenty people
# at once; in a timed comparison, the measurement itself.
#
# A /api/generate request with no prompt is Ollama's load-only form: it returns
# once the model is resident, having generated nothing. It has to be the native
# endpoint rather than /v1, since that is where keep_alive is accepted.
echo -n "Loading $MODEL into memory (slow on CPU) "
LOAD_STARTED=$SECONDS
if curl -sf --max-time 900 "http://${HOST}:${PORT}/api/generate" \
     -H 'Content-Type: application/json' \
     -d "{\"model\": \"${MODEL}\", \"keep_alive\": -1}" >/dev/null; then
  echo "— resident after $((SECONDS - LOAD_STARTED))s."
else
  # Not fatal: the model is on disk and will load lazily on the first real
  # query. Say so rather than exiting, since a server that answers slowly is
  # still more use mid-class than no server at all.
  echo >&2
  echo "WARNING: preload failed; the first query will pay the load cost." >&2
fi

# --- what to put on the board ----------------------------------------------
cat <<EOF

────────────────────────────────────────────────────────────
  Server URL — write this on the board:

      http://${HOST}:${PORT}

  Students' first step is the reach check on running-llms.md:

      curl http://${HOST}:${PORT}          # → Ollama is running

  then the same address as base_url="http://${HOST}:${PORT}/v1" from Python.
────────────────────────────────────────────────────────────

Serving. Ctrl-C stops the server; requests are logged to
${LOG} if you need to debug one.

EOF

# Hold the script in the foreground so the server is not orphaned — under
# `screen` this is the session you detach from, under sbatch it is what keeps
# the job alive. The log is written but not followed: the exercise no longer
# involves watching queries arrive, so it exists for debugging only.
wait "$SERVER_PID"
