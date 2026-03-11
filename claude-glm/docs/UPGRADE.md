# Upgrading Claude Code

Claude-GLM does not need to be upgraded separately — it automatically uses whatever Claude Code version is installed.

## How It Works

The wrapper script discovers the Claude Code binary at runtime:

1. **macOS/Linux:** Follows the `~/.local/bin/claude` symlink, which the Claude Code installer updates automatically
2. **Windows:** Checks standard install locations in priority order

When Claude Code updates itself, the wrapper automatically uses the new version.

## Updating Claude Code

### Native Installer (Recommended)

If you installed Claude Code via the native installer:

```bash
# Claude Code updates itself automatically, or:
claude update
```

The symlink at `~/.local/bin/claude` is updated to point to the new version.

### npm

```bash
npm update -g @anthropic-ai/claude-code
```

## Verifying the Update

```bash
# Check Claude Code version
claude-glm --version

# Should show the latest version
```

## If Something Breaks After Update

If claude-glm stops working after a Claude Code update:

1. **Check if Claude Code itself works:**
   ```bash
   claude --version
   ```

2. **Check binary path:**
   ```bash
   # macOS/Linux
   readlink ~/.local/bin/claude
   ls -la ~/.local/share/claude/versions/

   # Windows
   where claude
   ```

3. **Re-run the installer** if the binary location changed:
   ```bash
   ./install.sh
   ```

## Version Compatibility

Claude-GLM uses only public environment variables documented by Anthropic:
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_DEFAULT_*_MODEL`
- `CLAUDE_CONFIG_DIR`

These are stable across Claude Code versions. If Anthropic changes the env var interface, this project will be updated accordingly.
