#!/usr/bin/env bash
# glm-recover.sh — Aggregate GLM workflow state for post-compaction recovery
#
# Cross-platform (Windows Git Bash + macOS/Linux). Thin read-only helper:
# collects all state files the lead needs to resume work after compaction
# and prints them in a single stream so one Read call restores context.
#
# Prints (in order):
#   1. Memory session state (via memory.sh session show)
#   2. Current plan (tmp/glm-plan.md)
#   3. Continuation file (tmp/glm-continuation.md) — if present
#   4. Newest synthesis file by mtime (matches both stage and iteration
#      synthesis; the glob covers both since stage-*-synthesis.md also
#      matches stage-N-iter-K-synthesis.md)
#   5. Latest stage checklist (tmp/stage-*-checklist.md)
#
# Writes nothing. Safe to run anytime.
#
# Usage:
#   .opencode/tools/glm-recover.sh

set -euo pipefail

# ── Locate repo root so paths resolve regardless of CWD ──
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$REPO_ROOT"

# ── Helper: pick the newest file matching a glob pattern ──
# Uses bash -nt comparison (POSIX test), portable across Git Bash and macOS.
pick_latest() {
  local pattern="$1"
  local latest=""
  local f
  # Unquoted expansion so the glob runs; -f check handles no-match case
  # where the literal pattern stays in $pattern.
  for f in $pattern; do
    [[ -f "$f" ]] || continue
    if [[ -z "$latest" || "$f" -nt "$latest" ]]; then
      latest="$f"
    fi
  done
  printf '%s' "$latest"
}

# ── Helper: print a section, cat file or note its absence ──
print_section() {
  local title="$1"
  local file="$2"
  echo ""
  echo "=== ${title} ==="
  if [[ -n "$file" && -f "$file" ]]; then
    echo "(source: $file)"
    echo ""
    cat "$file"
  else
    echo "(not present)"
  fi
  echo ""
}

# ── Header ──
echo "================================================================"
echo "GLM WORKFLOW RECOVERY"
echo "Repo: $REPO_ROOT"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================"

# ── 1. Memory session state ──
echo ""
echo "=== MEMORY SESSION ==="
MEMORY_SH=".opencode/tools/memory.sh"
if [[ -x "$MEMORY_SH" ]]; then
  if ! "$MEMORY_SH" session show 2>&1; then
    echo "(memory.sh session show failed)"
  fi
elif [[ -f "$MEMORY_SH" ]]; then
  if ! bash "$MEMORY_SH" session show 2>&1; then
    echo "(memory.sh session show failed)"
  fi
else
  echo "(memory.sh not found at $MEMORY_SH)"
fi
echo ""

# ── 2. Plan ──
print_section "PLAN" "tmp/glm-plan.md"

# ── 3. Continuation (only if present) ──
if [[ -f "tmp/glm-continuation.md" ]]; then
  print_section "CONTINUATION" "tmp/glm-continuation.md"
fi

# ── 4. Newest synthesis (glob matches both stage-*-synthesis.md and
#      stage-*-iter-*-synthesis.md since * is greedy; pick by mtime) ──
LATEST_SYNTH="$(pick_latest 'tmp/stage-*-synthesis.md')"
print_section "LATEST SYNTHESIS" "$LATEST_SYNTH"

# ── 5. Latest checklist ──
LATEST_CHECK="$(pick_latest 'tmp/stage-*-checklist.md')"
print_section "LATEST CHECKLIST" "$LATEST_CHECK"

# ── Footer with recovery protocol reminder ──
echo "================================================================"
echo "RECOVERY DUMP COMPLETE"
echo ""
echo "Next steps (AGENTS.md compaction recovery protocol):"
echo "  1. Re-read AGENTS.md in full — MANDATORY, no partial reads"
echo "  2. Review the plan above to identify current stage"
echo "  3. If mid-verification: resume from first unlabeled checklist row"
echo "  4. If mid-iteration: continue from latest iteration synthesis"
echo "================================================================"
