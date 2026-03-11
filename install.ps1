# ============================================================================
# Opus-GLM Installer for Windows
#
# Installs the Opus-GLM orchestration system into a target project.
# Asks for your GLM Coding Plan to configure agent limits and model mappings.
#
# Usage:
#   .\install.ps1 C:\path\to\your\project     Install into project
#   .\install.ps1 -Help                        Show help
# ============================================================================

param(
    [Parameter(Position=0)]
    [string]$TargetPath,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Plan configuration
$PlanConfig = @{
    "max"  = @{ MaxAgents = 5; Lead = "glm-5";   Agents = "glm-4.7" }
    "pro"  = @{ MaxAgents = 3; Lead = "glm-5";   Agents = "glm-4.7" }
    "lite" = @{ MaxAgents = 1; Lead = "glm-4.7"; Agents = "glm-4.7" }
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> " -ForegroundColor Cyan -NoNewline
    Write-Host $Message -ForegroundColor White
}

function Show-Help {
    @"
Opus-GLM Installer for Windows

Installs the Opus-GLM orchestration system into a target project directory.

Usage:
  .\install.ps1 C:\path\to\your\project     Install into project
  .\install.ps1 -Help                        Show this help

What it does:
  1. Asks which GLM Coding Plan you have (Max/Pro/Lite)
  2. Copies .claude\ directory (agents, tools, templates) to your project
  3. Creates CLAUDE.md with Opus-GLM instructions configured for your plan
  4. Creates tmp\ directory for agent working files
  5. Optionally installs the claude-glm wrapper (for Z.ai GLM API)

Plan differences:
  Max  - up to 5 agents per stage, lead=glm-5, agents=glm-4.7
  Pro  - up to 3 agents per stage, lead=glm-5, agents=glm-4.7
  Lite - up to 1 agent per stage, lead=glm-4.7, agents=glm-4.7

After installation:
  - Open your project with Claude Code
  - Give it tasks - Opus-GLM activates automatically
"@
}

function Main {
    if ($Help) {
        Show-Help
        return
    }

    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        Write-Err "Target project path required"
        Write-Host ""
        Write-Host "Usage: .\install.ps1 C:\path\to\your\project"
        Write-Host ""
        exit 1
    }

    $Target = Resolve-Path $TargetPath -ErrorAction SilentlyContinue
    if (-not $Target) {
        Write-Err "Directory not found: $TargetPath"
        exit 1
    }
    $Target = $Target.Path

    Write-Host ""
    Write-Host "+======================================+" -ForegroundColor White
    Write-Host "|       Opus-GLM Installer             |" -ForegroundColor White
    Write-Host "+======================================+" -ForegroundColor White
    Write-Host ""
    Write-Host "  Target: $Target"

    # ── Step 1: GLM Plan Selection ──
    Write-Step "GLM Coding Plan Selection"

    Write-Host ""
    Write-Host "  Which GLM Coding Plan do you have?"
    Write-Host ""
    Write-Host "  [1] Max  " -NoNewline -ForegroundColor White
    Write-Host "- lead=glm-5,   agents=glm-4.7, up to 5 parallel agents"
    Write-Host "  [2] Pro  " -NoNewline -ForegroundColor White
    Write-Host "- lead=glm-5,   agents=glm-4.7, up to 3 parallel agents"
    Write-Host "  [3] Lite " -NoNewline -ForegroundColor White
    Write-Host "- lead=glm-4.7, agents=glm-4.7, up to 1 parallel agent"
    Write-Host ""

    $planName = $null
    $maxAgents = 3
    do {
        $choice = Read-Host "  Select plan [1/2/3]"
        switch ($choice) {
            "1" { $planName = "max";  $maxAgents = 5 }
            "2" { $planName = "pro";  $maxAgents = 3 }
            "3" { $planName = "lite"; $maxAgents = 1 }
            default { Write-Err "Invalid choice. Enter 1, 2, or 3." }
        }
    } while (-not $planName)

    $config = $PlanConfig[$planName]
    Write-Info "Plan: $planName - max $maxAgents agents per stage"

    # ── Step 2: Copy .claude\ ──
    Write-Step "Installing .claude\ directory"

    $claudeDir = Join-Path $Target ".claude"
    $srcClaude = Join-Path $ScriptDir ".claude"

    if (Test-Path $claudeDir) {
        Write-Warn ".claude\ directory already exists in target"
        Write-Host "  Merging new files (existing files will NOT be overwritten)..."

        Get-ChildItem -Path $srcClaude -Recurse -File | ForEach-Object {
            $relPath = $_.FullName.Substring($srcClaude.Length)
            $destFile = Join-Path $claudeDir $relPath
            $destDir = Split-Path $destFile -Parent

            if (-not (Test-Path $destFile)) {
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item $_.FullName $destFile
            }
        }
        Write-Info "Merged into existing .claude\"
    } else {
        Copy-Item -Path $srcClaude -Destination $claudeDir -Recurse
        Write-Info "Installed .claude\ directory"
    }

    # ── Step 3: CLAUDE.md ──
    Write-Step "Setting up CLAUDE.md"

    $claudeMd = Join-Path $Target "CLAUDE.md"
    $srcClaudeMd = Join-Path $ScriptDir "CLAUDE.md"

    if (Test-Path $claudeMd) {
        $content = Get-Content $claudeMd -Raw
        if ($content -match "Opus-GLM") {
            Write-Info "CLAUDE.md already contains Opus-GLM instructions"
            # Update max agents
            $content = $content -replace '\{\{MAX_AGENTS\}\}', $maxAgents
            [System.IO.File]::WriteAllText($claudeMd, $content, [System.Text.Encoding]::UTF8)
        } else {
            Write-Warn "CLAUDE.md exists but doesn't have Opus-GLM instructions"
            Write-Host "  You can append them manually:"
            Write-Host "    Get-Content $srcClaudeMd | Add-Content $claudeMd"
        }
    } else {
        $content = Get-Content $srcClaudeMd -Raw
        $content = $content -replace '\{\{MAX_AGENTS\}\}', $maxAgents
        [System.IO.File]::WriteAllText($claudeMd, $content, [System.Text.Encoding]::UTF8)
        Write-Info "Created CLAUDE.md (plan: $planName, max agents: $maxAgents)"
    }

    # ── Step 4: tmp\ directory ──
    Write-Step "Creating tmp\ directory"
    $tmpDir = Join-Path $Target "tmp"
    if (-not (Test-Path $tmpDir)) {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }
    Write-Info "Created tmp\ for agent working files"

    # ── Step 5: Claude-GLM wrapper (optional) ──
    Write-Step "Claude-GLM wrapper (Z.ai API)"

    Write-Host ""
    Write-Host "  The claude-glm wrapper lets Claude Code use Z.ai GLM models."
    Write-Host "  This is REQUIRED for spawning GLM agents."
    Write-Host ""
    $answer = Read-Host "  Install claude-glm wrapper? [Y/n]"

    if ($answer -match "^[nN]") {
        Write-Info "Skipping claude-glm installation"
        Write-Warn "You will need claude-glm in PATH for spawn-glm.sh to work"
    } else {
        Write-Host ""
        $glmInstaller = Join-Path $ScriptDir "claude-glm\install.ps1"
        & $glmInstaller -Plan $planName
    }

    # ── Done ──
    $agentCount = (Get-ChildItem (Join-Path $claudeDir "agents\*.md")).Count

    Write-Host ""
    Write-Host "+======================================+" -ForegroundColor Green
    Write-Host "|     Installation complete!            |" -ForegroundColor Green
    Write-Host "+======================================+" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Installed to: $Target"
    Write-Host "  Plan:         $planName (max $maxAgents agents per stage)"
    Write-Host ""
    Write-Host "  Contents:" -ForegroundColor White
    Write-Host "    .claude\agents\     $agentCount agent definitions"
    Write-Host "    .claude\tools\      Orchestration & memory tools"
    Write-Host "    .claude\templates\  Agent prompt boilerplate"
    Write-Host "    CLAUDE.md           Workflow instructions"
    Write-Host "    tmp\                Agent working directory"
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor White
    Write-Host "    cd $Target"
    Write-Host "    claude              # or claude-glm for Z.ai"
    Write-Host "    # Give it any task - Opus-GLM activates automatically"
    Write-Host ""
}

Main
