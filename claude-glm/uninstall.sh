#!/usr/bin/env bash
# ============================================================================
# Claude-GLM Uninstaller for macOS/Linux
# ============================================================================

set -Eeuo pipefail

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
step()  { printf '\n%s==>%s %s%s%s\n' "$CYAN" "$RESET" "$BOLD" "$*" "$RESET"; }

WRAPPER_PATH="$HOME/.local/bin/claude-glm"
CONFIG_DIR="$HOME/.claude-glm"

printf '\n%sClaude-GLM Uninstaller%s\n\n' "$BOLD" "$RESET"

# ── Remove wrapper ──
step "Removing wrapper script"

if [[ -f "$WRAPPER_PATH" ]]; then
  rm -- "$WRAPPER_PATH"
  info "Removed $WRAPPER_PATH"
else
  info "Wrapper not found at $WRAPPER_PATH (already removed?)"
fi

# ── Remove config ──
step "Config directory"

if [[ -d "$CONFIG_DIR" ]]; then
  printf '  Remove config directory %s? [y/N] ' "$CONFIG_DIR"
  read -r answer
  case "$answer" in
    [yY]|[yY][eE][sS])
      rm -rf -- "$CONFIG_DIR"
      info "Removed $CONFIG_DIR"
      ;;
    *)
      info "Keeping $CONFIG_DIR"
      ;;
  esac
else
  info "Config directory not found (already removed?)"
fi

# ── Done ──
printf '\n%sUninstall complete.%s\n\n' "$GREEN" "$RESET"
printf '  Claude Code itself was not modified.\n'
printf '  Your regular "claude" command still works normally.\n\n'
