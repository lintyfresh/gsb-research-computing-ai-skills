#!/bin/bash
# Make sure a shared Ollama server is up, and print its URL. Run this at the
# start of Day 4 — or, better, the evening before, so a busy GPU queue is a
# problem you discover with time to spare rather than in front of the room.
#
#     bash .instructor/ollama/ensure_ollama_server.sh
#
# In practice run one of the two wrappers instead — ensure_ollama_gpu.sh or
# ensure_ollama_cpu.sh — which are this script with the right settings already
# filled in. See the partition note below.
#
# Idempotent and safe to re-run: if a healthy server is already answering it
# prints the URL and exits without submitting anything. Otherwise it submits
# start_ollama_server.sh to the GPU partition and waits for it to answer.
#
# Unlike start_ollama_server.sh, this does not need an interactive session or
# `screen` — the server runs as a batch job, so it survives a dropped
# connection and a closed laptop.
#
# Environment overrides:
#   WALLTIME=4:00:00      how long the server should live; see the note below
#   RESERVATION=class_day4  the teaching reservation; the default, pass
#                         RESERVATION= to use the open queue instead
#   CONSTRAINT=...        which cards are eligible; see the default below
#   CPUS=8                cores for the server; matters a lot on CPU, see below
#   MODEL=llama3.2:1b     passed through to the server script
#
# Co-authored by Claude (Anthropic).

set -euo pipefail

SCRATCH_BASE="${SCRATCH_BASE:-/scratch/users/$USER}"
COORD_DIR="${SCRATCH_BASE}/ollama"

# An inherited SCRATCH_BASE beats the default above, and this is easy to hit by
# accident: DARC's own guide still says `export SCRATCH_BASE=/scratch/shared/$USER`
# (rcpedia, May 2025), which is the *superseded* per-user path — DARC confirmed
# 2026-08-02 that per-user scratch moved to /scratch/users/<user>/. Both
# directories still exist, so the old one fails silently rather than loudly:
# the server starts fine, just with weights and coordinates in the wrong place.
#
# /scratch/users/$USER is mode 700, so students cannot read host.txt/port.txt.
# That is the intended arrangement — read the URL out to the room.
#
# Note /scratch/shared/<project>/ paths (e.g. the course datasets) are a
# different thing entirely and are unaffected; only the per-user path moved.
echo "SCRATCH_BASE=$SCRATCH_BASE"
case "$SCRATCH_BASE" in
  */scratch/shared/*)
    cat >&2 <<WARN

  ⚠  That is the superseded per-user scratch path. Per-user scratch is now
     /scratch/users/\$USER — DARC's rcpedia guide has not been updated.
     Continuing, but weights and host.txt/port.txt will land in the old place.
     To use the current path:  unset SCRATCH_BASE

WARN
    ;;
esac
JOB_NAME="${JOB_NAME:-ollama-server}"

# Partition and GPU count are overridable so the same script can stand up the
# CPU contrast server alongside the GPU one — same image, same model, same
# queries, answers arriving a word at a time.
#
# You do not have to assemble those overrides by hand. Two wrappers next to this
# file do it, and they are what you should normally run:
#
#     bash .instructor/ollama/ensure_ollama_gpu.sh      # the GPU server
#     bash .instructor/ollama/ensure_ollama_cpu.sh      # the CPU one
#
# Run both, in either order, for the speed contrast. They are independent jobs.
#
# The CPU wrapper points SCRATCH_BASE at a separate tree, and that is not
# optional. ollama.sh keeps port.txt, host.txt and models under a single
# ${SCRATCH_BASE}/ollama, so two servers sharing one would overwrite each other's
# coordinates and you would lose track of the first. The cost is that the second
# tree re-downloads the ~2 GB of weights.
#
# --nv stays hardcoded in ollama.sh even with GPUS=0; on a CPU node Apptainer
# prints "Could not find any nv files on this host!" and continues (verified on
# yen20, 2026-08-02), so no patch to the helper is needed.
PARTITION="${PARTITION:-gpu}"
GPUS="${GPUS:-1}"

# Cores matter, and they matter asymmetrically. On a GPU node the weights sit in
# VRAM and the CPU only tokenises and marshals requests, so a couple of cores is
# plenty. On a CPU node llama.cpp *is* the inference engine and it threads across
# whatever it is given, so the core count sets the token rate directly.
#
# This defaulted to Slurm's implicit --cpus-per-task=1 until 2026-08-02, which
# made the CPU server a single-core worst case rather than a representative CPU
# node: job 406385 spent over four minutes merely loading llama3.2:3b before it
# could answer at all. Timing a GPU against that overstates the gap, and it is a
# fair thing for a student to object to.
#
# 8 is modest on a 256-core node and does not meaningfully slow scheduling.
# Memory follows cores rather than being requested separately: DefMemPerCPU is
# 4000M on `normal` and 3000M on `gpu`, so 8 cores brings ~32 GB and ~24 GB
# respectively — both comfortably above the ~2 GB the model needs.
CPUS="${CPUS:-8}"

# Day 4 is ~3 hours (docs/day4/index.md), so 4 gives an hour of slack for a late
# start or an overrun. The GPU is held for the *whole* walltime whether or not
# anyone is querying, so don't inflate this "just in case" — there are 14 GPUs on
# the cluster. If you pre-submit the evening before to dodge a morning queue, it
# has to span the gap *and* the session (e.g. WALLTIME=15:00:00 for a 9pm
# submission), which is still inside the gpu partition's 1-day cap.
WALLTIME="${WALLTIME:-4:00:00}"
# No GPU-model constraint by default. This used to pin the demo to A30/A40 to
# keep it off the scarce H200s, but the class reservation below *is* H200
# capacity, so the old default would have excluded the very node held for us and
# left the job pending against nothing. The reservation now does the node
# selection, and asking for a card model on top only narrows it further.
#
# Set CONSTRAINT="GPU_MODEL:A30|GPU_MODEL:A40" (or similar) if you are running
# without a reservation on the open queue, where staying off the big cards is
# still the courteous default — llama3.2:1b is ~1.3 GB quantised and does not
# need 141 GiB of VRAM.
CONSTRAINT="${CONSTRAINT-}"

# The teaching reservation, which holds GPU capacity aside for the class so the
# demo server does not queue behind whatever else is on the cluster that
# morning. `class_day4` is the Day 4 window. Outside it the name does not
# resolve and sbatch refuses the job ("Access denied to reservation"), so run
# with RESERVATION= to submit to the open queue instead — a dry run the week
# before, say. Bare `-` rather than `:-` so an explicit empty value wins.
RESERVATION="${RESERVATION-class_day4}"
MODEL="${MODEL:-llama3.2:1b}"
WAIT_SECONDS="${WAIT_SECONDS:-1800}"   # covers a cold image+model pull, and queueing

SERVER_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start_ollama_server.sh"

# --- is something already serving? -----------------------------------------
# Health-probe rather than trust the coordinate files: they are written at
# startup and never cleaned up, so after a job ends they still name a host and
# port with nothing behind them. Only a reply from the endpoint counts.
#
# And probe for the *model*, not the port. start_ollama_server.sh runs
# `ollama pull` only after the server has bound, so there is a window — minutes
# wide on a cold cache — in which GET / cheerfully answers "Ollama is running"
# while every real query returns `model 'llama3.2:1b' not found`. Announcing the
# URL during that window is the worst possible time to be wrong about it: the
# whole class queries at once and every one of them gets an error.
#
# /api/ps rather than /api/tags (changed 2026-08-02). `tags` lists what is on
# disk, which goes true the moment `ollama pull` finishes and so reopens the
# same problem one stage later: the server would be announced as ready while
# still loading the weights into memory, and on CPU that is minutes, not
# seconds. `ps` lists what is *resident*, which is the condition we actually
# mean by ready — and it is what the preload in start_ollama_server.sh
# establishes.
current_url() {
  [ -s "${COORD_DIR}/host.txt" ] && [ -s "${COORD_DIR}/port.txt" ] || return 1
  local host port
  host=$(<"${COORD_DIR}/host.txt")
  port=$(<"${COORD_DIR}/port.txt")
  curl -sf --max-time 5 "http://${host}:${port}/api/ps" 2>/dev/null \
    | grep -q "\"${MODEL}\"" || return 1
  printf 'http://%s:%s\n' "$host" "$port"
}

if url=$(current_url); then
  echo "A server is already up: $url"
  exit 0
fi

# --- is one already on its way? --------------------------------------------
# Re-running this while a job is queued or still pulling the container would
# otherwise burn a second GPU for a server nobody needs.
existing=$(squeue -u "$USER" -n "$JOB_NAME" -h -o %i 2>/dev/null | head -1 || true)

if [ -n "$existing" ]; then
  echo "Job $existing is already starting a server; waiting for it."
  jobid="$existing"
else
  mkdir -p "$COORD_DIR"     # sbatch needs the --output directory to exist
  # Clear stale coordinates so the wait below cannot be fooled by a port that
  # some unrelated process has since taken over on the old host.
  rm -f "${COORD_DIR}/host.txt" "${COORD_DIR}/port.txt"

  submit=(sbatch --parsable
          --job-name="$JOB_NAME"
          --partition="$PARTITION"
          --ntasks=1
          --cpus-per-task="$CPUS"
          --time="$WALLTIME"
          --output="${COORD_DIR}/slurm-%j.out")
  # The GPU-model constraint only means anything when we are asking for a GPU;
  # applying it to a `normal` node would make the job unschedulable outright.
  # The reservation goes the same way and for the same reason: class_day4 holds
  # GPU nodes, so a GPUS=0 job asking for it would never be scheduled — which
  # matters because the CPU contrast server in the header is exactly that job.
  if [ "$GPUS" -gt 0 ]; then
    submit+=(--gpus="$GPUS")
    [ -n "$CONSTRAINT" ] && submit+=(--constraint="$CONSTRAINT")
    [ -n "$RESERVATION" ] && submit+=(--reservation="$RESERVATION")
  fi

  # `bash -l` so the module system (and therefore `ml apptainer`) is defined.
  jobid=$(MODEL="$MODEL" "${submit[@]}" --wrap="MODEL='$MODEL' bash -l '$SERVER_SCRIPT'")
  echo "Submitted job $jobid to the $PARTITION partition (walltime $WALLTIME, GPUs: $GPUS${RESERVATION:+, reservation $RESERVATION})."
fi

# --- wait for it to answer --------------------------------------------------
echo -n "Waiting for the server to come up"
deadline=$((SECONDS + WAIT_SECONDS))
while [ "$SECONDS" -lt "$deadline" ]; do
  if url=$(current_url); then
    echo
    cat <<EOF

────────────────────────────────────────────────────────────
  Server URL — write this on the board:

      $url

  Students' first step is the reach check on running-llms.md:

      curl $url          # → Ollama is running

  then the same address as base_url="$url/v1" from Python.

  Job $jobid — logs in ${COORD_DIR}/
  Stop it with: scancel $jobid
────────────────────────────────────────────────────────────
EOF
    exit 0
  fi

  state=$(squeue -j "$jobid" -h -o %T 2>/dev/null || true)
  if [ -z "$state" ]; then
    echo
    echo "ERROR: job $jobid left the queue without serving. Last lines of its log:" >&2
    tail -20 "${COORD_DIR}/slurm-${jobid}.out" 2>/dev/null >&2 || echo "  (no log found)" >&2
    exit 1
  fi

  echo -n "."
  sleep 10
done

echo
echo "ERROR: no reply within $((WAIT_SECONDS / 60)) minutes. Job $jobid is $(squeue -j "$jobid" -h -o %T 2>/dev/null || echo gone)." >&2
echo "Check ${COORD_DIR}/slurm-${jobid}.out and ${COORD_DIR}/server.log." >&2
exit 1
