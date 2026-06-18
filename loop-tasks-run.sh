#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Loop Tasks Runner
# Reads loop-tasks.txt, processes pending tasks one by one
# via opencode agentic workflow, marks completed tasks
# with [x], commits progress, repeats until all done.
#
# Usage:   ./loop-tasks-run.sh
# Stop:    Ctrl+C
#
# Configuration: change OPENCODE_CMD and MODEL below
#  - OPENCODE_CMD: the opencode binary to invoke
#  - MODEL: model flag passed to opencode (e.g. "-m zai/glm-5.2")
# ============================================================

# ╔══════════════════════════════════════════════════════════════╗
# ║                      CONFIGURATION                          ║
# ╚══════════════════════════════════════════════════════════════╝
# OPENCODE_CMD — path or name of the opencode binary to invoke
#   opencode           → use opencode from PATH
#   opencode-lead      → use lead wrapper (model baked in, set MODEL="")
#   /path/to/opencode  → absolute path to a specific binary

OPENCODE_CMD="opencode"

#
# MODEL — model flag passed to opencode (leave empty for default)
#   ""                 → use opencode's configured default model
#   "-m zai/glm-5.2"   → use a specific model

MODEL=""

# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASKS_FILE="${SCRIPT_DIR}/loop-tasks.txt"
RUNS_DIR="${SCRIPT_DIR}/tmp/loop-runs"

# Platform-aware sed inline
case "$(uname -s)" in
    Darwin*) SED_I=(sed -i '') ;;
    *)       SED_I=(sed -i) ;;
esac

mkdir -p "$RUNS_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    log "FATAL: $*"
    exit 1
}

# ── Main Loop ─────────────────────────────────────────────────

while true; do

# ── Find next pending task ────────────────────────────────────

[[ -f "$TASKS_FILE" ]] || die "Tasks file not found: $TASKS_FILE"

# Find first line starting with [ ] (not [x])
NEXT_TASK=$(grep -n '^\[ \]' "$TASKS_FILE" | head -1 || true)

if [[ -z "$NEXT_TASK" ]]; then
    log "All tasks complete. Nothing to do."
    exit 0
fi

TASK_LINE_NUM=$(echo "$NEXT_TASK" | cut -d: -f1)
TASK_LINE=$(echo "$NEXT_TASK" | cut -d: -f2-)

# Extract task text: strip the "[ ] " prefix
TASK_TEXT="${TASK_LINE#\[ \] }"

log "========================================="
log "Next task (line ${TASK_LINE_NUM}):"
log "  ${TASK_TEXT}"
log "========================================="

# ── Build prompt ──────────────────────────────────────────────

PROMPT_FILE="${RUNS_DIR}/prompt.txt"

cat > "$PROMPT_FILE" << EOF
Re-read AGENTS.md in full and STRICTLY follow its instructions.

YOUR TASK: ${TASK_TEXT}

Start the work according to agentic workflow and work until task is 100% finished.
Commit and push all changes once everything is ready.
EOF

log "Prompt: ${PROMPT_FILE} ($(wc -c < "$PROMPT_FILE") bytes)"

# ── Run opencode ─────────────────────────────────────────────

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
OUTFILE="${RUNS_DIR}/run-${TIMESTAMP}.log"

log "Starting ${OPENCODE_CMD} ${MODEL}..."

START_TIME=$(date +%s)

${OPENCODE_CMD} \
    ${MODEL} \
    run \
    --dangerously-skip-permissions \
    --format json \
    < "$PROMPT_FILE" \
    &> "$OUTFILE" &
OPENCODE_PID=$!

log "PID: ${OPENCODE_PID}"

# Poll until done
LAST_SIZE=0
while kill -0 "$OPENCODE_PID" 2>/dev/null; do
    sleep 30
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    if [[ -f "$OUTFILE" ]]; then
        CUR_SIZE=$(wc -c < "$OUTFILE" 2>/dev/null | tr -d ' ')
        if [[ "$CUR_SIZE" != "$LAST_SIZE" ]]; then
            log "Running... ${ELAPSED}s, output: ${CUR_SIZE} bytes"
            LAST_SIZE="$CUR_SIZE"
        fi
    else
        log "Running... ${ELAPSED}s"
    fi
done

EXIT_CODE=0
wait "$OPENCODE_PID" 2>/dev/null || EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
log "${OPENCODE_CMD} finished in ${DURATION}s (exit: ${EXIT_CODE})"

if [[ $EXIT_CODE -ne 0 ]]; then
    log "${OPENCODE_CMD} exited with error. Stopping."
    log "Full output: ${OUTFILE}"
    exit 1
fi

log "Task completed successfully."

# ── Mark task as done ─────────────────────────────────────────

log "Marking line ${TASK_LINE_NUM} as [x]..."

"${SED_I[@]}" "${TASK_LINE_NUM}s/^\[ \]/[x]/" "$TASKS_FILE"

# ── Commit + Push progress ────────────────────────────────────

if [[ -n $(git -C "$SCRIPT_DIR" status --porcelain) ]]; then
    SHORT_TASK="$(echo "$TASK_TEXT" | cut -c1-70)"
    COMMIT_MSG="Loop tasks: ${SHORT_TASK}"
    log "Committing: ${COMMIT_MSG}"
    git -C "$SCRIPT_DIR" add -A
    git -C "$SCRIPT_DIR" commit -m "$COMMIT_MSG"
    git -C "$SCRIPT_DIR" push
    log "Committed and pushed."
else
    log "No uncommitted changes."
fi

log "---"
log "Task done. Moving to next..."
log ""

done
