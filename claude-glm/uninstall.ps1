# ============================================================================
# Claude-GLM Uninstaller for Windows
# ============================================================================

$ErrorActionPreference = "Stop"

$WrapperPath = Join-Path $env:USERPROFILE ".local\bin\claude-glm.cmd"
$ConfigDir = Join-Path $env:USERPROFILE ".claude-glm"

Write-Host ""
Write-Host "Claude-GLM Uninstaller" -ForegroundColor White
Write-Host ""

# ── Remove wrapper ──
Write-Host ""
Write-Host "==> " -ForegroundColor Cyan -NoNewline
Write-Host "Removing wrapper script"

if (Test-Path $WrapperPath) {
    Remove-Item $WrapperPath -Force
    Write-Host "[INFO] " -ForegroundColor Green -NoNewline
    Write-Host "Removed $WrapperPath"
} else {
    Write-Host "[INFO] " -ForegroundColor Green -NoNewline
    Write-Host "Wrapper not found at $WrapperPath (already removed?)"
}

# ── Remove config ──
Write-Host ""
Write-Host "==> " -ForegroundColor Cyan -NoNewline
Write-Host "Config directory"

if (Test-Path $ConfigDir) {
    $answer = Read-Host "  Remove config directory $ConfigDir ? [y/N]"
    if ($answer -match "^[yY]") {
        Remove-Item $ConfigDir -Recurse -Force
        Write-Host "[INFO] " -ForegroundColor Green -NoNewline
        Write-Host "Removed $ConfigDir"
    } else {
        Write-Host "[INFO] " -ForegroundColor Green -NoNewline
        Write-Host "Keeping $ConfigDir"
    }
} else {
    Write-Host "[INFO] " -ForegroundColor Green -NoNewline
    Write-Host "Config directory not found (already removed?)"
}

# ── Done ──
Write-Host ""
Write-Host "Uninstall complete." -ForegroundColor Green
Write-Host ""
Write-Host "  Claude Code itself was not modified."
Write-Host "  Your regular 'claude' command still works normally."
Write-Host ""
