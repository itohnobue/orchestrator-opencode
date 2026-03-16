#!/usr/bin/env bash
# ============================================================================
# Opus-GLM Installer
#
# Installs the Opus-GLM orchestration system into a target project.
# Asks for your GLM Coding Plan to configure agent limits and model mappings.
# Optionally installs the claude-glm wrapper for Z.ai GLM API access.
#
# Usage:
#   ./install.sh /path/to/your/project     Install into project
#   ./install.sh --help                     Show help
# ============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# ── Colors ──
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

info()  { printf '%s[INFO]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n' "$RED" "$RESET" "$*" >&2; }
step()  { printf '\n%s==>%s %s%s%s\n' "$CYAN" "$RESET" "$BOLD" "$*" "$RESET"; }

show_help() {
  cat <<'HELP'
Opus-GLM Installer

Installs the Opus-GLM orchestration system into a target project directory.

Usage:
  ./install.sh /path/to/your/project     Install into project
  ./install.sh --help                     Show this help

What it does:
  1. Asks which GLM Coding Plan you have (Max/Pro/Lite)
  2. Copies .claude/ directory (agents, tools, templates) to your project
  3. Creates CLAUDE.md with Opus-GLM instructions configured for your plan
  4. Creates tmp/ directory for agent working files
  5. Optionally installs the claude-glm wrapper (for Z.ai GLM API)

Plan differences:
  Max  — up to 5 agents per stage, lead=glm-5, agents=glm-4.7
  Pro  — up to 3 agents per stage, lead=glm-5, agents=glm-4.7
  Lite — up to 1 agent per stage, lead=glm-4.7, agents=glm-4.7

After installation:
  - Open your project with Claude Code
  - Give it tasks — Opus-GLM activates automatically
HELP
}

# ── Main ──
main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
  fi

  local target="${1:-}"

  if [[ -z "$target" ]]; then
    error "Target project path required"
    printf '\nUsage: ./install.sh /path/to/your/project\n\n'
    exit 1
  fi

  if [[ ! -d "$target" ]]; then
    error "Directory not found: $target"
    exit 1
  fi

  target="$(cd "$target" && pwd -P)"

  printf '\n%s╔══════════════════════════════════════╗%s\n' "$BOLD" "$RESET"
  printf '%s║       Opus-GLM Installer             ║%s\n' "$BOLD" "$RESET"
  printf '%s╚══════════════════════════════════════╝%s\n\n' "$BOLD" "$RESET"

  printf '  Target: %s\n' "$target"

  # ── Step 1: GLM Plan Selection ──
  step "GLM Coding Plan Selection"

  printf '\n'
  printf '  Which GLM Coding Plan do you have?\n'
  printf '\n'
  printf '  %s[1] Max%s  — lead=glm-5,   agents=glm-4.7, up to 5 parallel agents\n' "$BOLD" "$RESET"
  printf '  %s[2] Pro%s  — lead=glm-5,   agents=glm-4.7, up to 3 parallel agents\n' "$BOLD" "$RESET"
  printf '  %s[3] Lite%s — lead=glm-4.7, agents=glm-4.7, up to 1 parallel agent\n' "$BOLD" "$RESET"
  printf '\n'

  local plan_choice plan_name max_agents
  while true; do
    printf '  Select plan [1/2/3]: '
    read -r plan_choice

    case "$plan_choice" in
      1) plan_name="max";  max_agents=5; break ;;
      2) plan_name="pro";  max_agents=3; break ;;
      3) plan_name="lite"; max_agents=1; break ;;
      *) error "Invalid choice. Enter 1, 2, or 3." ;;
    esac
  done

  info "Plan: $plan_name — max $max_agents agents per stage"

  # ── Step 2: Copy .claude/ ──
  step "Installing .claude/ directory"

  if [[ -d "$target/.claude" ]]; then
    warn ".claude/ directory already exists in target"
    printf '  Merging new files (existing files will NOT be overwritten)...\n'
    # Copy without overwriting — try multiple methods for portability
    if rsync -a --ignore-existing "$SCRIPT_DIR/.claude/" "$target/.claude/" 2>/dev/null; then
      : # rsync worked
    else
      # Fallback: manual copy (works on all platforms)
      find "$SCRIPT_DIR/.claude" -type f | while IFS= read -r src; do
        rel="${src#"$SCRIPT_DIR/"}"
        dst="$target/$rel"
        if [[ ! -f "$dst" ]]; then
          mkdir -p "$(dirname "$dst")"
          cp "$src" "$dst"
        fi
      done
    fi
    info "Merged into existing .claude/"
  else
    cp -r "$SCRIPT_DIR/.claude" "$target/.claude"
    info "Installed .claude/ directory"
  fi

  # Ensure all .sh scripts are executable (fixes macOS clone without +x)
  find "$target/.claude" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
  find "$SCRIPT_DIR/claude-glm" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

  # ── Step 3: CLAUDE.md ──
  step "Setting up CLAUDE.md"

  if [[ -f "$target/CLAUDE.md" ]]; then
    if grep -q "Opus-GLM" "$target/CLAUDE.md" 2>/dev/null; then
      info "CLAUDE.md already contains Opus-GLM instructions"
      # Update max agents in existing CLAUDE.md
      sed -i.bak "s/{{MAX_AGENTS}}/$max_agents/g" "$target/CLAUDE.md" 2>/dev/null && rm -f "$target/CLAUDE.md.bak" || \
        sed -i '' "s/{{MAX_AGENTS}}/$max_agents/g" "$target/CLAUDE.md" 2>/dev/null || true
    else
      warn "CLAUDE.md exists but doesn't have Opus-GLM instructions"
      printf '  You can append them manually:\n'
      printf '    cat %s/CLAUDE.md >> %s/CLAUDE.md\n\n' "$SCRIPT_DIR" "$target"
    fi
  else
    cp "$SCRIPT_DIR/CLAUDE.md" "$target/CLAUDE.md"
    # Replace max agents placeholder
    sed -i.bak "s/{{MAX_AGENTS}}/$max_agents/g" "$target/CLAUDE.md" 2>/dev/null && rm -f "$target/CLAUDE.md.bak" || \
      sed -i '' "s/{{MAX_AGENTS}}/$max_agents/g" "$target/CLAUDE.md" 2>/dev/null || true
    info "Created CLAUDE.md (plan: $plan_name, max agents: $max_agents)"
  fi

  # ── Step 4: tmp/ directory ──
  step "Creating tmp/ directory"
  mkdir -p "$target/tmp"
  info "Created tmp/ for agent working files"

  # ── Step 5: Claude-GLM wrapper (optional) ──
  step "Claude-GLM wrapper (Z.ai API)"

  printf '\n  The claude-glm wrapper lets Claude Code use Z.ai GLM models.\n'
  printf '  This is REQUIRED for spawning GLM agents.\n\n'
  printf '  Install claude-glm wrapper? [Y/n] '
  read -r answer
  case "$answer" in
    [nN]|[nN][oO])
      info "Skipping claude-glm installation"
      warn "You will need claude-glm in PATH for spawn-glm.sh to work"
      ;;
    *)
      printf '\n'
      "$SCRIPT_DIR/claude-glm/install.sh" --plan "$plan_name"
      ;;
  esac

  # ── Done ──
  printf '\n'
  printf '%s╔══════════════════════════════════════╗%s\n' "$GREEN" "$RESET"
  printf '%s║     Installation complete!            ║%s\n' "$GREEN" "$RESET"
  printf '%s╚══════════════════════════════════════╝%s\n' "$GREEN" "$RESET"
  printf '\n'
  printf '  Installed to: %s\n' "$target"
  printf '  Plan:         %s (max %s agents per stage)\n' "$plan_name" "$max_agents"
  printf '\n'
  printf '  %sContents:%s\n' "$BOLD" "$RESET"
  printf '    .claude/agents/     %s agent definitions\n' "$(find "$target/.claude/agents" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  printf '    .claude/tools/      Orchestration & memory tools\n'
  printf '    .claude/templates/  Agent prompt boilerplate\n'
  printf '    CLAUDE.md           Workflow instructions\n'
  printf '    tmp/                Agent working directory\n'
  printf '\n'
  printf '  %sUsage:%s\n' "$BOLD" "$RESET"
  printf '    cd %s\n' "$target"
  printf '    claude              # or claude-glm for Z.ai\n'
  printf '    # Give it any task — Opus-GLM activates automatically\n'
  printf '\n'
}

main "$@"
