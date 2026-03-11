# ============================================================================
# Claude-GLM Installer for Windows
#
# Installs the claude-glm wrapper that lets Claude Code use Z.ai GLM models.
#
# Usage:
#   .\install.ps1              Interactive install
#   .\install.ps1 -Help        Show help
#
# Requirements:
#   - Claude Code (https://claude.ai/download)
#   - Z.ai API key (https://bigmodel.cn/usercenter/proj-mgmt/apikeys)
#   - Z.ai GLM Coding Plan (https://z.ai/subscribe)
# ============================================================================

param(
    [switch]$Help,
    [string]$Plan = ""
)

$ErrorActionPreference = "Stop"

# ── Constants ──

$CLAUDE_GLM_VERSION = "1.0.0"
$ZAI_API_BASE = "https://api.z.ai/api/anthropic"
$CONFIG_DIR_NAME = ".claude-glm"
$WRAPPER_NAME = "claude-glm.cmd"

# Model mappings per plan
$PlanModels = @{
    "max"  = @{ Opus = "glm-5";   Sonnet = "glm-4.7"; Haiku = "glm-4.7" }
    "pro"  = @{ Opus = "glm-5";   Sonnet = "glm-4.7"; Haiku = "glm-4.7" }
    "lite" = @{ Opus = "glm-4.7"; Sonnet = "glm-4.7"; Haiku = "glm-4.7" }
}

# ── Helpers ──

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
Claude-GLM Installer for Windows

Installs the claude-glm wrapper that lets Claude Code use Z.ai GLM models
instead of the native Anthropic API.

Usage:
  .\install.ps1              Interactive install
  .\install.ps1 -Help        Show this help

What it does:
  1. Detects your Claude Code installation
  2. Asks for your Z.ai API key
  3. Asks which GLM Coding Plan you have
  4. Creates config directory (%USERPROFILE%\.claude-glm\)
  5. Installs wrapper script (%USERPROFILE%\.local\bin\claude-glm.cmd)
  6. Ensures %USERPROFILE%\.local\bin is in your PATH

Requirements:
  - Claude Code installed (https://claude.ai/download)
  - Z.ai API key (https://bigmodel.cn/usercenter/proj-mgmt/apikeys)
  - Z.ai GLM Coding Plan subscription (https://z.ai/subscribe)
"@
}

# ── Claude Code Binary Discovery ──

function Find-ClaudeBinary {
    $userProfile = $env:USERPROFILE

    # Method 1: Native installer
    $nativePath = Join-Path $userProfile ".local\bin\claude.exe"
    if (Test-Path $nativePath) {
        return $nativePath
    }

    # Method 2: npm global
    $npmPath = Join-Path $env:APPDATA "npm\claude.cmd"
    if (Test-Path $npmPath) {
        return $npmPath
    }

    # Method 3: AppData standalone
    $appDataPath = Join-Path $env:LOCALAPPDATA "Programs\claude\claude.exe"
    if (Test-Path $appDataPath) {
        return $appDataPath
    }

    # Method 4: PATH
    $inPath = Get-Command claude -ErrorAction SilentlyContinue
    if ($inPath) {
        return $inPath.Source
    }

    return $null
}

# ── API Key Validation ──

function Test-ApiKey {
    param([string]$ApiKey)

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Err "API key is empty"
        return $false
    }

    Write-Info "Testing API connectivity..."

    try {
        $body = '{"model":"glm-4.7-flash","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}'
        $headers = @{
            "x-api-key"         = $ApiKey
            "anthropic-version" = "2023-06-01"
            "content-type"      = "application/json"
        }

        $response = Invoke-WebRequest `
            -Uri "$ZAI_API_BASE/v1/messages" `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -TimeoutSec 30 `
            -UseBasicParsing `
            -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            Write-Info "API key validated successfully"
            return $true
        } else {
            Write-Err "API returned HTTP $($response.StatusCode). Check your API key."
            return $false
        }
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        if ($statusCode) {
            Write-Err "API returned HTTP $statusCode. Check your API key."
            return $false
        } else {
            Write-Warn "Could not reach Z.ai API (network issue?). Continuing anyway."
            return $true
        }
    }
}

# ── PATH Management ──

function Ensure-PathEntry {
    $binDir = Join-Path $env:USERPROFILE ".local\bin"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if ($currentPath -split ";" | Where-Object { $_ -eq $binDir }) {
        return
    }

    Write-Info "Adding $binDir to user PATH"
    $newPath = "$binDir;$currentPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$binDir;$env:Path"
    Write-Warn "PATH updated. Restart your terminal for the change to take effect."
}

# ── Write file without BOM ──

function Write-NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    # CRITICAL: Use ASCII encoding to avoid UTF-8 BOM that breaks JSON parsing
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::ASCII)
}

# ── Main ──

function Main {
    if ($Help) {
        Show-Help
        return
    }

    Write-Host ""
    Write-Host "+======================================+" -ForegroundColor White
    Write-Host "|     Claude-GLM Installer v$CLAUDE_GLM_VERSION     |" -ForegroundColor White
    Write-Host "+======================================+" -ForegroundColor White
    Write-Host ""

    # ── Step 1: Check Claude Code ──
    Write-Step "Checking Claude Code installation"

    $claudeBin = Find-ClaudeBinary
    if ($claudeBin) {
        Write-Info "Found Claude Code: $claudeBin"
    } else {
        Write-Err "Claude Code not found!"
        Write-Host ""
        Write-Host "  Install Claude Code first:"
        Write-Host "    https://claude.ai/download"
        Write-Host ""
        Write-Host "  Or via npm:"
        Write-Host "    npm install -g @anthropic-ai/claude-code"
        Write-Host ""
        exit 1
    }

    # ── Step 2: Get API key ──
    Write-Step "Z.ai API Key"

    Write-Host "  Get your key from: https://bigmodel.cn/usercenter/proj-mgmt/apikeys"
    Write-Host ""

    $apiKey = $null
    while ($true) {
        $secureKey = Read-Host "  Enter your Z.ai API key" -AsSecureString
        $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
        )

        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Err "API key cannot be empty"
            continue
        }

        if (Test-ApiKey -ApiKey $apiKey) {
            break
        }

        Write-Host ""
        Write-Host "  Try again or press Ctrl+C to cancel."
        Write-Host ""
    }

    # ── Step 3: Select plan ──
    Write-Step "GLM Coding Plan Selection"

    $planName = $null

    if ($Plan -and @("max","pro","lite") -contains $Plan) {
        # Plan passed from main installer
        $planName = $Plan
        Write-Info "Using plan from main installer: $planName"
    } else {
        Write-Host ""
        Write-Host "  Which GLM Coding Plan do you have?"
        Write-Host ""
        Write-Host "  [1] Max  " -NoNewline -ForegroundColor White
        Write-Host "- opus=glm-5,   sonnet=glm-4.7, haiku=glm-4.7"
        Write-Host "  [2] Pro  " -NoNewline -ForegroundColor White
        Write-Host "- opus=glm-5,   sonnet=glm-4.7, haiku=glm-4.7"
        Write-Host "  [3] Lite " -NoNewline -ForegroundColor White
        Write-Host "- opus=glm-4.7,  sonnet=glm-4.7, haiku=glm-4.7"
        Write-Host ""

        do {
            $choice = Read-Host "  Select plan [1/2/3]"
            switch ($choice) {
                "1" { $planName = "max" }
                "2" { $planName = "pro" }
                "3" { $planName = "lite" }
                default { Write-Err "Invalid choice. Enter 1, 2, or 3." }
            }
        } while (-not $planName)
    }

    $models = $PlanModels[$planName]
    Write-Info "Plan: $planName -> opus=$($models.Opus), sonnet=$($models.Sonnet), haiku=$($models.Haiku)"

    # ── Step 4: Create config directory ──
    Write-Step "Creating config directory"

    $configDir = Join-Path $env:USERPROFILE $CONFIG_DIR_NAME

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # .credentials.json
    $credPath = Join-Path $configDir ".credentials.json"
    if (-not (Test-Path $credPath)) {
        Write-NoBom -Path $credPath -Content '{"apiKeyAuth":{"source":"environment"}}'
        Write-Info "Created $credPath"
    } else {
        Write-Info "Keeping existing $credPath"
    }

    # .claude.json
    $claudeJsonPath = Join-Path $configDir ".claude.json"
    if (-not (Test-Path $claudeJsonPath)) {
        Write-NoBom -Path $claudeJsonPath -Content '{"hasCompletedOnboarding":true,"onboardingComplete":true,"customApiKeyResponses":{"approved":[],"rejected":[]},"bypassPermissionsModeAccepted":true}'
        Write-Info "Created $claudeJsonPath"
    } else {
        Write-Info "Keeping existing $claudeJsonPath"
    }

    # settings.json
    $settingsPath = Join-Path $configDir "settings.json"
    Write-NoBom -Path $settingsPath -Content '{"model":"opus"}'
    Write-Info "Created $settingsPath"

    # ── Step 5: Generate wrapper script ──
    Write-Step "Installing wrapper script"

    $installDir = Join-Path $env:USERPROFILE ".local\bin"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    $wrapperPath = Join-Path $installDir $WRAPPER_NAME
    $today = Get-Date -Format "yyyy-MM-dd"

    # Read template and replace placeholders
    $templatePath = Join-Path $PSScriptRoot "scripts\claude-glm.cmd"
    $template = Get-Content $templatePath -Raw

    # Use [string]::Replace for API key to avoid regex interpretation of special chars
    $wrapper = $template.Replace('{{API_KEY}}', $apiKey).Replace('{{PLAN_NAME}}', $planName).Replace('{{OPUS_MODEL}}', $models.Opus).Replace('{{SONNET_MODEL}}', $models.Sonnet).Replace('{{HAIKU_MODEL}}', $models.Haiku).Replace('{{VERSION}}', $CLAUDE_GLM_VERSION).Replace('{{DATE}}', $today)

    Write-NoBom -Path $wrapperPath -Content $wrapper
    Write-Info "Installed $wrapperPath"

    # ── Step 6: Ensure PATH ──
    Write-Step "Checking PATH"
    Ensure-PathEntry

    # ── Step 7: Verify ──
    Write-Step "Verification"

    $glmCmd = Get-Command claude-glm -ErrorAction SilentlyContinue
    if ($glmCmd) {
        Write-Info "claude-glm is accessible in PATH"
    } else {
        Write-Warn "claude-glm not found in PATH - restart your terminal"
    }

    # ── Done ──
    Write-Host ""
    Write-Host "+======================================+" -ForegroundColor Green
    Write-Host "|     Installation complete!            |" -ForegroundColor Green
    Write-Host "+======================================+" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Wrapper:  $wrapperPath"
    Write-Host "  Config:   $configDir"
    Write-Host "  Plan:     $planName (opus=$($models.Opus), sonnet=$($models.Sonnet), haiku=$($models.Haiku))"
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor White
    Write-Host "    claude-glm            Start Claude Code with GLM"
    Write-Host "    claude-glm --version  Check version"
    Write-Host "    claude-glm --help     Show help"
    Write-Host ""
    Write-Host "  If the command is not found, restart your terminal."
    Write-Host ""
}

Main
