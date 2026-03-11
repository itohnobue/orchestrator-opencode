# Claude-GLM

Use [Claude Code](https://claude.ai/download) with [Z.ai](https://z.ai) GLM models instead of the native Anthropic API.

Claude-GLM is a lightweight wrapper that redirects Claude Code to the Z.ai GLM API. No binary patching — it sets environment variables and exec's the original Claude Code binary.

## Quick Start

### macOS / Linux

```bash
git clone https://git.aoizora.ru/nobu/claude-glm.git
cd claude-glm
./install.sh
```

### Windows (PowerShell)

```powershell
git clone https://git.aoizora.ru/nobu/claude-glm.git
cd claude-glm
.\install.ps1
```

The installer will ask for your Z.ai API key and which plan you have, then configure everything automatically.

## Requirements

- **Claude Code** — [Download](https://claude.ai/download)
- **Z.ai API key** — [Get one](https://bigmodel.cn/usercenter/proj-mgmt/apikeys)
- **GLM Coding Plan** — [Subscribe](https://z.ai/subscribe) (Lite, Pro, or Max)

## How It Works

Claude Code supports environment variable overrides for API endpoint and model selection. Claude-GLM:

1. Unsets OAuth tokens to prevent auth conflicts
2. Sets `ANTHROPIC_API_KEY` to your Z.ai key
3. Points `ANTHROPIC_BASE_URL` to `https://api.z.ai/api/anthropic`
4. Maps Claude model aliases (opus/sonnet/haiku) to GLM models
5. Uses a separate config directory (`~/.claude-glm/`) to avoid conflicts
6. Exec's the real Claude Code binary

Your regular `claude` command is not affected.

## Model Mappings

The installer configures model mappings based on your GLM Coding Plan:

| Claude Alias | Max Plan | Pro Plan | Lite Plan |
|-------------|----------|----------|-----------|
| **opus** | glm-5 | glm-5 | glm-4.7 |
| **sonnet** | glm-4.7 | glm-4.7 | glm-4.7 |
| **haiku** | glm-4.7 | glm-4.7 | glm-4.7 |

## Configuration

### Change API Key

Edit the wrapper script directly:

- **macOS/Linux:** `~/.local/bin/claude-glm`
- **Windows:** `%USERPROFILE%\.local\bin\claude-glm.cmd`

Find the `ANTHROPIC_API_KEY` line and replace the value.

### Change Plan / Models

Re-run the installer — it will overwrite the wrapper with new model mappings. Existing config files are preserved.

### Custom Models

Edit the `ANTHROPIC_DEFAULT_*_MODEL` variables in the wrapper script to use any model available on the Z.ai API.

### Config Directory

All Claude-GLM configuration is stored in `~/.claude-glm/`:

| File | Purpose |
|------|---------|
| `.credentials.json` | Tells Claude Code to use API key from environment |
| `.claude.json` | Onboarding flags for seamless first-run |
| `settings.json` | Default model setting (opus) |

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

**Quick fixes:**

- **"Claude Code not found"** — Install Claude Code first: https://claude.ai/download
- **Auth errors** — Make sure you don't have `ANTHROPIC_AUTH_TOKEN` set in your environment
- **First-run dialogs** — Delete `~/.claude-glm/.claude.json` and re-run the installer
- **Command not found** — Restart your terminal or add `~/.local/bin` to PATH

## Uninstall

### macOS / Linux

```bash
./uninstall.sh
```

### Windows

```powershell
.\uninstall.ps1
```

This removes the wrapper script and optionally the config directory. Claude Code itself is not modified.

## License

MIT
