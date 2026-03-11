#!/usr/bin/env bash
# ============================================================================
# Claude-GLM: Shared functions for installer and wrapper scripts
# ============================================================================

set -Eeuo pipefail

# ── Constants ──

readonly CLAUDE_GLM_VERSION="1.0.0"
readonly ZAI_API_BASE="https://api.z.ai/api/anthropic"
readonly CONFIG_DIR_NAME=".claude-glm"
readonly WRAPPER_NAME="claude-glm"

# Model mappings per plan
# Format: OPUS SONNET HAIKU
readonly PLAN_MAX_MODELS="glm-5 glm-4.7 glm-4.7"
readonly PLAN_PRO_MODELS="glm-5 glm-4.7 glm-4.7"
readonly PLAN_LITE_MODELS="glm-4.7 glm-4.7 glm-4.7"

# ── Colors ──

if [[ -t 1 ]]; then
  readonly RED=$'\033[0;31m'
  readonly GREEN=$'\033[0;32m'
  readonly YELLOW=$'\033[0;33m'
  readonly CYAN=$'\033[0;36m'
  readonly BOLD=$'\033[1m'
  readonly RESET=$'\033[0m'
else
  readonly RED=''
  readonly GREEN=''
  readonly YELLOW=''
  readonly CYAN=''
  readonly BOLD=''
  readonly RESET=''
fi

# ── Logging ──

info() {
  printf '%s[INFO]%s %s\n' "$GREEN" "$RESET" "$*"
}

warn() {
  printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2
}

error() {
  printf '%s[ERROR]%s %s\n' "$RED" "$RESET" "$*" >&2
}

step() {
  printf '\n%s==>%s %s%s%s\n' "$CYAN" "$RESET" "$BOLD" "$*" "$RESET"
}

# ── Claude Code Binary Discovery ──

# Find the Claude Code binary on macOS/Linux.
# Prints the absolute path to stdout. Returns 1 if not found.
find_claude_binary() {
  # Method 1: Native installer symlink
  if [[ -L "$HOME/.local/bin/claude" ]]; then
    local target
    target="$(readlink "$HOME/.local/bin/claude" 2>/dev/null || true)"
    if [[ -n "$target" ]]; then
      # Resolve relative symlinks against symlink's directory
      [[ "$target" != /* ]] && target="$HOME/.local/bin/$target"
      if [[ -x "$target" ]]; then
        printf '%s' "$target"
        return 0
      fi
    fi
  fi

  # Method 2: Latest version in versions directory
  local versions_dir="$HOME/.local/share/claude/versions"
  if [[ -d "$versions_dir" ]]; then
    local latest
    latest="$(ls "$versions_dir" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
    if [[ -n "$latest" && -x "$versions_dir/$latest" ]]; then
      printf '%s' "$versions_dir/$latest"
      return 0
    fi
  fi

  # Method 3: claude in PATH (but not ourselves)
  if command -v claude &>/dev/null; then
    local claude_path
    claude_path="$(command -v claude)"
    if [[ "$(basename "$claude_path")" != "claude-glm" ]]; then
      printf '%s' "$claude_path"
      return 0
    fi
  fi

  return 1
}

# Parse model list for a given plan name.
# Usage: get_plan_models "max" → sets OPUS_MODEL, SONNET_MODEL, HAIKU_MODEL
get_plan_models() {
  local plan="$1"
  local models

  case "$plan" in
    max)  models="$PLAN_MAX_MODELS" ;;
    pro)  models="$PLAN_PRO_MODELS" ;;
    lite) models="$PLAN_LITE_MODELS" ;;
    *)
      error "Unknown plan: $plan"
      return 1
      ;;
  esac

  read -r OPUS_MODEL SONNET_MODEL HAIKU_MODEL <<< "$models"
  export OPUS_MODEL SONNET_MODEL HAIKU_MODEL
}

# Validate API key by making a test request.
# Returns 0 on success, 1 on failure.
validate_api_key() {
  local api_key="$1"

  if [[ -z "$api_key" ]]; then
    error "API key is empty"
    return 1
  fi

  if ! command -v curl &>/dev/null; then
    warn "curl not found, skipping API key validation"
    return 0
  fi

  info "Testing API connectivity..."
  local http_code
  http_code="$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST \
    -H "x-api-key: $api_key" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    --connect-timeout 10 \
    --max-time 30 \
    -d '{"model":"glm-4.7-flash","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}' \
    "${ZAI_API_BASE}/v1/messages" 2>/dev/null || printf '000')"

  if [[ "$http_code" == "200" ]]; then
    info "API key validated successfully"
    return 0
  elif [[ "$http_code" == "000" ]]; then
    warn "Could not reach Z.ai API (network issue?). Continuing anyway."
    return 0
  else
    error "API returned HTTP $http_code. Check your API key."
    return 1
  fi
}

# Detect the user's shell config file.
detect_shell_rc() {
  local shell_name
  shell_name="$(basename "${SHELL:-/bin/bash}")"

  case "$shell_name" in
    zsh)  printf '%s' "$HOME/.zshrc" ;;
    bash) printf '%s' "$HOME/.bashrc" ;;
    fish) printf '%s' "$HOME/.config/fish/config.fish" ;;
    *)    printf '%s' "$HOME/.profile" ;;
  esac
}

# Ensure ~/.local/bin is in PATH. Add to shell rc if missing.
ensure_path() {
  local bin_dir="$HOME/.local/bin"

  if [[ ":$PATH:" == *":$bin_dir:"* ]]; then
    return 0
  fi

  local rc_file shell_name line
  rc_file="$(detect_shell_rc)"
  shell_name="$(basename "${SHELL:-/bin/bash}")"

  if [[ "$shell_name" == "fish" ]]; then
    line="fish_add_path $bin_dir"
  else
    line="export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi

  if [[ -f "$rc_file" ]] && grep -qF "$bin_dir" "$rc_file" 2>/dev/null; then
    return 0
  fi

  info "Adding $bin_dir to PATH in $rc_file"
  printf '\n# Added by claude-glm installer\n%s\n' "$line" >> "$rc_file"
  warn "Restart your terminal or run: source $rc_file"
}
