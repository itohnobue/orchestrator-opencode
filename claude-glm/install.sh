#!/usr/bin/env bash
# ============================================================================
# Claude-GLM Installer for macOS/Linux
#
# Installs the claude-glm wrapper that lets Claude Code use Z.ai GLM models.
#
# Usage:
#   ./install.sh              Interactive install
#   ./install.sh --help       Show help
#
# Requirements:
#   - Claude Code (https://claude.ai/download)
#   - Z.ai API key (https://bigmodel.cn/usercenter/proj-mgmt/apikeys)
#   - Z.ai GLM Coding Plan (https://z.ai/subscribe)
# ============================================================================

set -Eeuo pipefail

# ── Script directory ──
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/scripts/common.sh"

# ── Cleanup trap ──
cleanup() {
  # Nothing to clean up currently, but ready for future use
  :
}
trap cleanup EXIT

# ── Help ──
show_help() {
  cat <<'HELP'
Claude-GLM Installer

Installs the claude-glm wrapper that lets Claude Code use Z.ai GLM models
instead of the native Anthropic API.

Usage:
  ./install.sh              Interactive install
  ./install.sh --help       Show this help

What it does:
  1. Detects your Claude Code installation
  2. Asks for your Z.ai API key
  3. Asks which GLM Coding Plan you have
  4. Creates config directory (~/.claude-glm/)
  5. Installs wrapper script (~/.local/bin/claude-glm)
  6. Ensures ~/.local/bin is in your PATH

Requirements:
  - Claude Code installed (https://claude.ai/download)
  - Z.ai API key (https://bigmodel.cn/usercenter/proj-mgmt/apikeys)
  - Z.ai GLM Coding Plan subscription (https://z.ai/subscribe)
HELP
}

# ── Main ──
main() {
  local cli_plan=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) show_help; exit 0 ;;
      --plan)    cli_plan="$2"; shift 2 ;;
      *)         shift ;;
    esac
  done

  printf '\n%s╔══════════════════════════════════════╗%s\n' "$BOLD" "$RESET"
  printf '%s║     Claude-GLM Installer v%s     ║%s\n' "$BOLD" "$CLAUDE_GLM_VERSION" "$RESET"
  printf '%s╚══════════════════════════════════════╝%s\n\n' "$BOLD" "$RESET"

  # ── Step 1: Check Claude Code ──
  step "Checking Claude Code installation"

  local claude_bin
  if claude_bin="$(find_claude_binary)"; then
    info "Found Claude Code: $claude_bin"
  else
    error "Claude Code not found!"
    printf '\n'
    printf '  Install Claude Code first:\n'
    printf '    https://claude.ai/download\n'
    printf '\n'
    printf '  Or via npm:\n'
    printf '    npm install -g @anthropic-ai/claude-code\n'
    printf '\n'
    exit 1
  fi

  # ── Step 2: Get API key ──
  step "Z.ai API Key"

  printf '  Get your key from: https://bigmodel.cn/usercenter/proj-mgmt/apikeys\n\n'

  local api_key
  while true; do
    printf '  Enter your Z.ai API key: '
    read -rs api_key
    printf '\n'

    if [[ -z "$api_key" ]]; then
      error "API key cannot be empty"
      continue
    fi

    if validate_api_key "$api_key"; then
      break
    fi

    printf '\n'
    printf '  Try again or press Ctrl+C to cancel.\n\n'
  done

  # ── Step 3: Select plan ──
  step "GLM Coding Plan Selection"

  local plan_choice plan_name

  if [[ -n "$cli_plan" ]]; then
    # Plan passed via --plan argument (from main installer)
    case "$cli_plan" in
      max|pro|lite) plan_name="$cli_plan" ;;
      *) error "Invalid plan: $cli_plan (expected max, pro, or lite)"; exit 1 ;;
    esac
    info "Using plan from main installer: $plan_name"
  else
    printf '\n'
    printf '  Which GLM Coding Plan do you have?\n'
    printf '\n'
    printf '  %s[1] Max%s  — opus=glm-5,   sonnet=glm-4.7, haiku=glm-4.7\n' "$BOLD" "$RESET"
    printf '  %s[2] Pro%s  — opus=glm-5,   sonnet=glm-4.7, haiku=glm-4.7\n' "$BOLD" "$RESET"
    printf '  %s[3] Lite%s — opus=glm-4.7,  sonnet=glm-4.7, haiku=glm-4.7\n' "$BOLD" "$RESET"
    printf '\n'

    while true; do
      printf '  Select plan [1/2/3]: '
      read -r plan_choice

      case "$plan_choice" in
        1) plan_name="max";  break ;;
        2) plan_name="pro";  break ;;
        3) plan_name="lite"; break ;;
        *) error "Invalid choice. Enter 1, 2, or 3." ;;
      esac
    done
  fi

  get_plan_models "$plan_name"
  info "Plan: $plan_name → opus=$OPUS_MODEL, sonnet=$SONNET_MODEL, haiku=$HAIKU_MODEL"

  # ── Step 4: Create config directory ──
  step "Creating config directory"

  local config_dir="$HOME/$CONFIG_DIR_NAME"
  (umask 077; mkdir -p "$config_dir")

  # .credentials.json
  if [[ ! -f "$config_dir/.credentials.json" ]]; then
    printf '{"apiKeyAuth":{"source":"environment"}}' > "$config_dir/.credentials.json"
    info "Created $config_dir/.credentials.json"
  else
    info "Keeping existing $config_dir/.credentials.json"
  fi

  # .claude.json
  if [[ ! -f "$config_dir/.claude.json" ]]; then
    printf '{"hasCompletedOnboarding":true,"onboardingComplete":true,"customApiKeyResponses":{"approved":[],"rejected":[]},"bypassPermissionsModeAccepted":true}' > "$config_dir/.claude.json"
    info "Created $config_dir/.claude.json"
  else
    info "Keeping existing $config_dir/.claude.json"
  fi

  # settings.json — always overwrite with correct model setting
  printf '{"model":"opus"}' > "$config_dir/settings.json"
  info "Created $config_dir/settings.json"

  # ── Step 5: Generate wrapper script ──
  step "Installing wrapper script"

  local install_dir="$HOME/.local/bin"
  mkdir -p "$install_dir"

  local wrapper_path="$install_dir/$WRAPPER_NAME"
  local today
  today="$(date +%Y-%m-%d)"

  # Escape sed special characters in API key (& \ |)
  local escaped_key
  escaped_key="$(printf '%s' "$api_key" | sed 's/[&\|/]/\\&/g')"

  sed \
    -e "s|{{API_KEY}}|$escaped_key|g" \
    -e "s|{{PLAN_NAME}}|$plan_name|g" \
    -e "s|{{OPUS_MODEL}}|$OPUS_MODEL|g" \
    -e "s|{{SONNET_MODEL}}|$SONNET_MODEL|g" \
    -e "s|{{HAIKU_MODEL}}|$HAIKU_MODEL|g" \
    -e "s|{{VERSION}}|$CLAUDE_GLM_VERSION|g" \
    -e "s|{{DATE}}|$today|g" \
    "$SCRIPT_DIR/scripts/claude-glm.sh" > "$wrapper_path"

  chmod 700 "$wrapper_path"
  info "Installed $wrapper_path"

  # ── Step 6: Ensure PATH ──
  step "Checking PATH"
  ensure_path

  # ── Step 7: Verify ──
  step "Verification"

  # Re-check PATH for this session
  export PATH="$install_dir:$PATH"

  if command -v claude-glm &>/dev/null; then
    info "claude-glm is accessible in PATH"
  else
    warn "claude-glm not found in PATH — restart your terminal"
  fi

  # ── Done ──
  printf '\n'
  printf '%s╔══════════════════════════════════════╗%s\n' "$GREEN" "$RESET"
  printf '%s║     Installation complete!            ║%s\n' "$GREEN" "$RESET"
  printf '%s╚══════════════════════════════════════╝%s\n' "$GREEN" "$RESET"
  printf '\n'
  printf '  Wrapper:  %s\n' "$wrapper_path"
  printf '  Config:   %s\n' "$config_dir"
  printf '  Plan:     %s (opus=%s, sonnet=%s, haiku=%s)\n' \
    "$plan_name" "$OPUS_MODEL" "$SONNET_MODEL" "$HAIKU_MODEL"
  printf '\n'
  printf '  %sUsage:%s\n' "$BOLD" "$RESET"
  printf '    claude-glm            Start Claude Code with GLM\n'
  printf '    claude-glm --version  Check version\n'
  printf '    claude-glm --help     Show help\n'
  printf '\n'
  printf '  If the command is not found, restart your terminal or run:\n'
  printf '    source %s\n' "$(detect_shell_rc)"
  printf '\n'
}

main "$@"
