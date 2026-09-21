param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "==> $Message"
    }
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $ProjectRoot ".runtime"
$PidPath = Join-Path $RuntimeDir "api.pid"
$UrlPath = Join-Path $RuntimeDir "api.url"

if (-not (Test-Path $PidPath)) {
    if (-not $Quiet) {
        Write-Host "No local deployment PID file found."
    }
    exit 0
}

$rawPid = (Get-Content $PidPath -Raw).Trim()
if (-not $rawPid) {
    Remove-Item $PidPath -Force
    if (-not $Quiet) {
        Write-Host "Removed empty local deployment PID file."
    }
    exit 0
}

try {
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
