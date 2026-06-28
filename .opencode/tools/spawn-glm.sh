#!/usr/bin/env bash
# spawn-glm.sh — Spawn one agent for Orchestration Workflow
#
# Pipes prompt from file through stdin to OpenCode CLI. Uses opencode's
# configured default model. Pass -m to override with a specific model.
# Stdin piping avoids shell escaping issues with complex prompt content.
#
# Agents run until completion — no max-turns limit.
#
# Usage:
#   .opencode/tools/spawn-glm.sh -n NAME -f PROMPT_FILE [-m MODEL]
#
# Arguments:
#   -n, --name         Agent name (log: ${REPO_ROOT}/tmp/{NAME}-log.txt)
#   -f, --prompt-file  Path to the prompt text file
#   -m, --model        Model to use (optional, defaults to opencode's configured model)
#
# Output (stdout):
#   SPAWNED|name|pid|log_file
#
# Examples:
#   .opencode/tools/spawn-glm.sh -n sec-reviewer -f ${REPO_ROOT}/tmp/sec-reviewer-prompt.txt
#   .opencode/tools/spawn-glm.sh -n s1-reviewer -f ${REPO_ROOT}/tmp/s1-reviewer-prompt.txt -m zai/glm-5.1

set -euo pipefail

# ── Resolve repo root so tmp/ paths are always ./tmp ──
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$REPO_ROOT"

command -v opencode &>/dev/null || \
  { echo "ERROR: opencode not found in PATH. Install OpenCode first." >&2; exit 1; }

# ── Parse arguments ──
NAME="" PROMPT_FILE="" MODEL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)        NAME="$2";        shift 2 ;;
    -f|--prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    -m|--model)       MODEL="$2";       shift 2 ;;
    -h|--help)        sed -n '2,/^$/p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "ERROR: Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ──
[[ -z "$NAME" ]]        && { echo "ERROR: -n NAME required" >&2; exit 1; }
[[ -z "$PROMPT_FILE" ]] && { echo "ERROR: -f PROMPT_FILE required" >&2; exit 1; }
[[ ! -f "$PROMPT_FILE" ]] && \
  { echo "ERROR: Prompt file not found: $PROMPT_FILE" >&2; exit 1; }
[[ ! -s "$PROMPT_FILE" ]] && \
  { echo "ERROR: Prompt file is empty: $PROMPT_FILE" >&2; exit 1; }

# Reject NAME values that would enable path traversal or break filenames
case "$NAME" in
  */*|*\\*|*\|*|*\&*|*\$*)
    echo "ERROR: NAME contains unsafe characters (/, \\, |, &, \$): $NAME" >&2
    exit 1
    ;;
esac

mkdir -p "${REPO_ROOT}/tmp"
LOG="${REPO_ROOT}/tmp/${NAME}-log.txt"
STATUS="${REPO_ROOT}/tmp/${NAME}-status.txt"

# ── Spawn: pipe prompt file → opencode run ──
# Model defaults to opencode's configured model; -m overrides when provided.
if [[ -n "$MODEL" ]]; then
  opencode run \
    -m "$MODEL" \
    --format json \
    < "$PROMPT_FILE" > "$LOG" 2>&1 &
else
  opencode run \
    --format json \
    < "$PROMPT_FILE" > "$LOG" 2>&1 &
fi

PID=$!

RESULT="SPAWNED|${NAME}|${PID}|${LOG}"

# Write to status file (reliable) + stdout (best-effort).
printf '%s\n' "$RESULT" > "$STATUS"
echo "$RESULT"
