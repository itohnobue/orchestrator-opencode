#!/usr/bin/env bash
# spawn-glm.sh — Spawn one GLM worker for GLM-OpenCode orchestration
#
# Pipes prompt from file through stdin to OpenCode CLI. Uses the default
# model configured in OpenCode — no model selection needed. Stdin piping
# avoids shell escaping issues with complex prompt content.
#
# Agents run until completion — no max-turns limit.
#
# Usage:
#   .opencode/tools/spawn-glm.sh -n NAME -f PROMPT_FILE
#
# Arguments:
#   -n, --name         Agent name (log: tmp/{NAME}-log.txt)
#   -f, --prompt-file  Path to the prompt text file
#   -m, --model        Override model (e.g. deepseek/deepseek-v4-flash). Default: opencode default
#
# Output (stdout):
#   SPAWNED|name|pid|log_file
#
# Examples:
#   .opencode/tools/spawn-glm.sh -n sec-reviewer -f tmp/sec-reviewer-prompt.txt
#   .opencode/tools/spawn-glm.sh -n s1-2nd -f tmp/s1-2nd-prompt.txt -m deepseek/deepseek-v4-flash

set -euo pipefail

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

mkdir -p tmp
LOG="tmp/${NAME}-log.txt"
STATUS="tmp/${NAME}-status.txt"

# ── Spawn: pipe prompt file → opencode run ──
# Uses default model configured in OpenCode unless -m is specified. No max-turns — agents run until completion.
MODEL_ARGS=()
[[ -n "$MODEL" ]] && MODEL_ARGS=(-m "$MODEL")

opencode run \
  ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
  --format json \
  < "$PROMPT_FILE" > "$LOG" 2>&1 &

PID=$!

RESULT="SPAWNED|${NAME}|${PID}|${LOG}"

# Write to status file (reliable) + stdout (best-effort).
printf '%s\n' "$RESULT" > "$STATUS"
echo "$RESULT"
