# Troubleshooting

## Common Issues

### "Claude Code binary not found"

Claude Code must be installed before using claude-glm.

**Fix:** Install Claude Code from https://claude.ai/download

The wrapper looks for Claude Code in these locations:

**macOS/Linux:**
1. `~/.local/bin/claude` (native installer symlink)
2. `~/.local/share/claude/versions/` (latest version)
3. `claude` in PATH

**Windows:**
1. `%USERPROFILE%\.local\bin\claude.exe` (native installer)
2. `%APPDATA%\npm\claude.cmd` (npm global)
3. `%LOCALAPPDATA%\Programs\claude\claude.exe` (standalone)
4. `claude` in PATH

### Authentication Errors

**Symptom:** `401 Unauthorized` or `Invalid API key` errors.

**Causes & Fixes:**

1. **Wrong API key** — Verify your key at https://bigmodel.cn/usercenter/proj-mgmt/apikeys

2. **Auth token conflict** — If you see errors about conflicting tokens, make sure `ANTHROPIC_AUTH_TOKEN` is not set in your shell environment:
   ```bash
   # Check
   echo $ANTHROPIC_AUTH_TOKEN

   # Clear (add to ~/.zshrc or ~/.bashrc to persist)
   unset ANTHROPIC_AUTH_TOKEN
   unset CLAUDE_CODE_OAUTH_TOKEN
   ```

3. **macOS Keychain interference** — Claude Code may try to use stored OAuth credentials. Clear them:
   ```bash
   security delete-generic-password -s "Claude Code-credentials" 2>/dev/null
   ```

### First-Run Dialogs Appearing

**Symptom:** Claude Code shows onboarding screens or login prompts when launched via claude-glm.

**Fix:** Delete and recreate the config:
```bash
rm ~/.claude-glm/.claude.json
# Then run claude-glm again — the wrapper auto-creates it
```

Or manually create it:
```bash
printf '{"hasCompletedOnboarding":true,"onboardingComplete":true,"customApiKeyResponses":{"approved":[],"rejected":[]},"bypassPermissionsModeAccepted":true}' > ~/.claude-glm/.claude.json
```

### "command not found: claude-glm"

**Fix:** Ensure `~/.local/bin` is in your PATH:

```bash
# Check
echo $PATH | tr ':' '\n' | grep .local/bin

# Add to shell config
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Windows:** Restart your terminal. The installer adds the path automatically, but it requires a new terminal session.

### Streaming Hangs ("Simmering..." forever)

**Symptom:** Claude Code hangs indefinitely after sending a large prompt.

**Cause:** Z.ai's streaming API has issues with request bodies larger than ~50KB. Claude Code sends large system prompts with tool definitions that can exceed this.

**Workarounds:**
- Keep prompts shorter
- Reduce the number of tools/MCP servers loaded
- The `API_TIMEOUT_MS=3000000` setting (50 min) prevents hard timeouts, but if the hang persists, press Ctrl+C and retry with a simpler prompt

This is a Z.ai server-side limitation.

### Windows: JSON Config File Corruption

**Symptom:** Claude Code fails to parse config files or shows unexpected errors on Windows.

**Cause:** PowerShell's default `Set-Content -Encoding UTF8` adds a UTF-8 BOM (Byte Order Mark) that breaks JSON parsing.

**Fix:** Recreate config files with ASCII encoding:
```powershell
[System.IO.File]::WriteAllText(
  "$env:USERPROFILE\.claude-glm\settings.json",
  '{"model":"opus"}',
  [System.Text.Encoding]::ASCII
)
```

The installer uses ASCII encoding by default to prevent this.

### Quota Exceeded

**Symptom:** `429 Too Many Requests` or quota-related errors.

**Cause:** You've exceeded your GLM Coding Plan's prompt quota for the current 5-hour cycle.

**Fix:** Wait for the quota to reset (5-hour rolling window), or upgrade your plan at https://z.ai/subscribe.

## Environment Variables

These environment variables are set by the claude-glm wrapper. If you encounter issues, check that they're correct:

| Variable | Expected Value |
|----------|---------------|
| `ANTHROPIC_API_KEY` | Your Z.ai API key |
| `ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` |
| `API_TIMEOUT_MS` | `3000000` |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` |
| `CLAUDE_CONFIG_DIR` | `~/.claude-glm` |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Depends on plan |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Depends on plan |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Depends on plan |

Variables that must NOT be set:
- `ANTHROPIC_AUTH_TOKEN` — Conflicts with API key auth
- `CLAUDE_CODE_OAUTH_TOKEN` — Conflicts with API key auth

## Getting Help

If your issue isn't listed here:
1. Check the wrapper script for correct values
2. Try running Claude Code directly to see if the issue is specific to GLM
3. Check Z.ai status at https://z.ai
