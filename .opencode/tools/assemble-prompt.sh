#!/usr/bin/env bash
# assemble-prompt.sh — Compose a full GLM agent prompt from agent .md + templates + task content
#
# Cross-platform (Windows Git Bash + macOS/Linux). Handles mechanical assembly
# so the lead only writes the task-specific parts (TASK ASSIGNMENT block).
#
# Reads the agent .md, selects templates for the task type, substitutes {NAME},
# appends the lead's task file, and writes the complete prompt to tmp/.
#
# Usage:
#   .opencode/tools/assemble-prompt.sh -a AGENT -t TYPE -n NAME --task TASK_FILE [-o OUT]
#
# Arguments:
#   -a, --agent       Agent name — reads .opencode/agents/{agent}.md
#   -t, --task-type   Task type: review | code | research
#   -n, --name        Agent instance name (e.g. s1-reviewer, s2i1-impl-auth)
#   --task            Path to task assignment file (PROJECT, ENVIRONMENT,
#                     PRIOR CONTEXT, YOUR TASK, WRITABLE FILES — lead-written)
#   -o, --output      Override output path (default: tmp/{name}-prompt.txt)
#
# Task type → template selection:
#   review:   coordination-review + severity-guide + quality-rules-review
#   code:     coordination-code   +                  quality-rules-code
#   research: coordination-review +                  quality-rules-review
#
# Output (stdout):
#   ASSEMBLED|name|output_path|bytes
#
# Example:
#   .opencode/tools/assemble-prompt.sh \
#     -a code-reviewer -t review -n s1-reviewer \
#     --task tmp/s1-reviewer-task.txt

set -euo pipefail

# ── Locate repo assets (templates, agents) via SCRIPT_DIR ──
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
AGENTS_DIR="$REPO_ROOT/.opencode/agents"
TEMPLATES_DIR="$REPO_ROOT/.opencode/templates"

# ── Parse arguments ──
AGENT="" TYPE="" NAME="" TASK_FILE="" OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--agent)     AGENT="$2";     shift 2 ;;
    -t|--task-type) TYPE="$2";      shift 2 ;;
    -n|--name)      NAME="$2";      shift 2 ;;
    --task)         TASK_FILE="$2"; shift 2 ;;
    -o|--output)    OUTPUT="$2";    shift 2 ;;
    -h|--help)      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "ERROR: Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Validate required args ──
[[ -z "$AGENT" ]]     && { echo "ERROR: -a AGENT required" >&2; exit 1; }
[[ -z "$TYPE" ]]      && { echo "ERROR: -t TYPE required (review|code|research)" >&2; exit 1; }
[[ -z "$NAME" ]]      && { echo "ERROR: -n NAME required" >&2; exit 1; }
[[ -z "$TASK_FILE" ]] && { echo "ERROR: --task FILE required" >&2; exit 1; }

# Reject NAME values that would break sed {NAME} substitution or filenames
case "$NAME" in
  */*|*\|*|*\&*|*\$*)
    echo "ERROR: NAME contains unsafe characters (/, |, &, \$): $NAME" >&2
    exit 1
    ;;
esac

# ── Resolve input files ──
AGENT_MD="$AGENTS_DIR/${AGENT}.md"
[[ ! -f "$AGENT_MD" ]]   && { echo "ERROR: Agent file not found: $AGENT_MD" >&2; exit 1; }
[[ ! -s "$AGENT_MD" ]]   && { echo "ERROR: Agent file is empty: $AGENT_MD" >&2; exit 1; }
[[ ! -f "$TASK_FILE" ]]  && { echo "ERROR: Task file not found: $TASK_FILE" >&2; exit 1; }
[[ ! -s "$TASK_FILE" ]]  && { echo "ERROR: Task file is empty: $TASK_FILE" >&2; exit 1; }

# ── Select templates based on task type ──
INCLUDE_SEVERITY=false
case "$TYPE" in
  review)
    COORDINATION="$TEMPLATES_DIR/coordination-review.txt"
    QUALITY="$TEMPLATES_DIR/quality-rules-review.txt"
    SEVERITY="$TEMPLATES_DIR/severity-guide.txt"
    INCLUDE_SEVERITY=true
    ;;
  research)
    COORDINATION="$TEMPLATES_DIR/coordination-review.txt"
    QUALITY="$TEMPLATES_DIR/quality-rules-review.txt"
    SEVERITY=""
    ;;
  code)
    COORDINATION="$TEMPLATES_DIR/coordination-code.txt"
    QUALITY="$TEMPLATES_DIR/quality-rules-code.txt"
    SEVERITY=""
    ;;
  *)
    echo "ERROR: Invalid task type '$TYPE' — must be review|code|research" >&2
    exit 1
    ;;
esac

# ── Validate templates exist ──
for f in "$COORDINATION" "$QUALITY"; do
  [[ ! -f "$f" ]] && { echo "ERROR: Template not found: $f" >&2; exit 1; }
  [[ ! -s "$f" ]] && { echo "ERROR: Template is empty: $f" >&2; exit 1; }
done
if [[ "$INCLUDE_SEVERITY" == "true" ]]; then
  [[ ! -f "$SEVERITY" ]] && { echo "ERROR: Template not found: $SEVERITY" >&2; exit 1; }
  [[ ! -s "$SEVERITY" ]] && { echo "ERROR: Template is empty: $SEVERITY" >&2; exit 1; }
fi

# ── Output path ──
[[ -z "$OUTPUT" ]] && OUTPUT="tmp/${NAME}-prompt.txt"
OUT_DIR="$(dirname "$OUTPUT")"
mkdir -p "$OUT_DIR"

# ── Assemble prompt ──
# Use | as sed delimiter so NAME containing / would be flagged above; here
# we use a safe character class already validated.
{
  printf 'You are a GLM agent named %s.\n\n' "$NAME"
  printf 'Before claiming something is missing or broken — grep for existing guards, handlers, or implementations first.\n\n'
  cat "$AGENT_MD"
  printf '\n\n--- TASK ASSIGNMENT ---\n\n'
  cat "$TASK_FILE"
  printf '\n\n'
  sed "s|{NAME}|${NAME}|g" "$COORDINATION"
  printf '\n\n'
  if [[ "$INCLUDE_SEVERITY" == "true" ]]; then
    cat "$SEVERITY"
    printf '\n\n'
  fi
  cat "$QUALITY"
  printf '\n'
} > "$OUTPUT"

# ── Validate non-empty output ──
[[ ! -s "$OUTPUT" ]] && { echo "ERROR: Output file is empty after assembly: $OUTPUT" >&2; exit 1; }

BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')
echo "ASSEMBLED|${NAME}|${OUTPUT}|${BYTES}"
