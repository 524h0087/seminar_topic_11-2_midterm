param(
    [switch]$Quiet # Suppresses all console output when set.
)

# Treat every error as terminating so failures are not silently ignored.
$ErrorActionPreference = "Stop"

# Prints a blank line followed by a "==> <message>" step header, unless -Quiet is set.
function Write-Step {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "==> $Message"
    }
}

# Project root (parent of the scripts folder).
$ProjectRoot = Split-Path -Parent $PSScriptRoot # seminar_topic_11-2_midterm/

# Folder holding the local deployment's runtime state.
$RuntimeDir = Join-Path $ProjectRoot ".runtime" # seminar_topic_11-2_midterm/.runtime

# File storing the PID of the running API process (written by deploy-local.ps1).
$PidPath = Join-Path $RuntimeDir "api.pid" # seminar_topic_11-2_midterm/.runtime/api.pid

# File storing the base URL of the running API (written by deploy-local.ps1).
$UrlPath = Join-Path $RuntimeDir "api.url" # seminar_topic_11-2_midterm/.runtime/api.url

if (-not (Test-Path $PidPath)) {
    if (-not $Quiet) {
        Write-Host "No local deployment PID file found."
    }
    exit 0
}

# PID text read from the PID file.
$rawPid = (Get-Content $PidPath -Raw).Trim()
if (-not $rawPid) {
    Remove-Item $PidPath -Force
    if (-not $Quiet) {
        Write-Host "Removed empty local deployment PID file."
    }
    exit 0
}

try {
    # Running API process matching the recorded PID; throws if it no longer exists.
    $process = Get-Process -Id ([int]$rawPid) -ErrorAction Stop
    Write-Step "Stopping local deployment with PID $($process.Id)"
    Stop-Process -Id $process.Id -Force
    $process.WaitForExit()
    if (-not $Quiet) {
        Write-Host "Local deployment stopped."
    }
} catch {
    if (-not $Quiet) {
        Write-Host "Recorded local deployment process was not running."
    }
} finally {
    Remove-Item $PidPath, $UrlPath -Force -ErrorAction SilentlyContinue
}
