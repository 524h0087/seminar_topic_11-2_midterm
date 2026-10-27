param(
    [string]$HostName = "127.0.0.1", # Host address uvicorn binds to.
    [int]$Port = 8080, # Port uvicorn listens on.
    [switch]$SkipBuild, # Skips running build.ps1 before deploying.
    [switch]$Force # Stops any existing local deployment before starting a new one.
)

# Treat every error as terminating so the deployment fails fast.
$ErrorActionPreference = "Stop"

# Prints a blank line followed by a "==> <message>" step header.
function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

# Returns the given relative path joined onto the project root.
function Resolve-FromProjectRoot {
    param([string]$Path)
    Join-Path $ProjectRoot $Path
}

# Polls the health endpoint until it reports status "UP"; throws after the timeout.
function Wait-ForHealth {
    param(
        [string]$HealthUrl, # Health endpoint to poll.
        [int]$TimeoutSeconds = 30 # Maximum time to wait before failing.
    )

    # Point in time after which polling gives up.
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $response = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2
            if ($response.status -eq "UP") {
                return
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)

    throw "API health check did not become ready at $HealthUrl within $TimeoutSeconds seconds."
}

# Returns the running API process recorded in api.pid, or $null if none.
# Deletes a stale PID file whose process no longer exists.
function Get-RecordedProcess {
    if (-not (Test-Path $PidPath)) {
        return $null
    }

    # PID text read from the PID file.
    $rawPid = (Get-Content $PidPath -Raw).Trim()
    if (-not $rawPid) {
        return $null
    }

    try {
        return Get-Process -Id ([int]$rawPid) -ErrorAction Stop
    } catch {
        Remove-Item $PidPath -Force
        return $null
    }
}

# Project root (parent of the scripts folder).
$ProjectRoot = Split-Path -Parent $PSScriptRoot # seminar_topic_11-2_midterm/

# Python executable inside the virtual environment, used to run uvicorn.
$PythonInVenv = Resolve-FromProjectRoot ".venv\Scripts\python.exe" # seminar_topic_11-2_midterm/.venv/Scripts/python.exe

# Folder holding runtime state (PID, URL, logs) for the local deployment.
$RuntimeDir = Resolve-FromProjectRoot ".runtime" # seminar_topic_11-2_midterm/.runtime

# File storing the PID of the running API process.
$PidPath = Join-Path $RuntimeDir "api.pid" # seminar_topic_11-2_midterm/.runtime/api.pid

# File storing the base URL of the running API.
$UrlPath = Join-Path $RuntimeDir "api.url" # seminar_topic_11-2_midterm/.runtime/api.url

# Log file for the API's standard output.
$OutputLogPath = Join-Path $RuntimeDir "api.out.log" # seminar_topic_11-2_midterm/.runtime/api.out.log

# Log file for the API's standard error.
$ErrorLogPath = Join-Path $RuntimeDir "api.err.log" # seminar_topic_11-2_midterm/.runtime/api.err.log

# Base URL the API is served at.
$BaseUrl = "http://${HostName}:$Port" # http://127.0.0.1:8080

# Health endpoint used to confirm the API is ready.
$HealthUrl = "$BaseUrl/actuator/health" # http://127.0.0.1:8080/actuator/health

Set-Location $ProjectRoot

if ($Force) {
    Write-Step "Stopping previous local deployment if it exists"
    & (Resolve-FromProjectRoot "scripts\stop-local.ps1")
}

# Already-running deployment, if any; reused instead of starting a second one.
$existingProcess = Get-RecordedProcess
if ($existingProcess) {
    Write-Step "Existing local deployment found with PID $($existingProcess.Id)"
    Wait-ForHealth -HealthUrl $HealthUrl
    Write-Host ""
    Write-Host "Local deployment is already running."
    Write-Host "URL: $BaseUrl"
    Write-Host "PID: $($existingProcess.Id)"
    exit 0
}

if (-not $SkipBuild) {
    Write-Step "Running Build phase before local deployment"
    & (Resolve-FromProjectRoot "scripts\build.ps1")
}

if (-not (Test-Path $PythonInVenv)) {
    throw "Missing virtual environment Python at $PythonInVenv. Run scripts\build.ps1 first."
}

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

Write-Step "Starting local deployment at $BaseUrl"
# Hidden background uvicorn process serving the API, with output redirected to the log files.
$deployedProcess = Start-Process `
    -FilePath $PythonInVenv `
    -ArgumentList @("-m", "uvicorn", "main:app", "--host", $HostName, "--port", "$Port") `
    -WorkingDirectory $ProjectRoot `
    -RedirectStandardOutput $OutputLogPath `
    -RedirectStandardError $ErrorLogPath `
    -PassThru `
    -WindowStyle Hidden

Set-Content -Path $PidPath -Value $deployedProcess.Id
Set-Content -Path $UrlPath -Value $BaseUrl

try {
    Wait-ForHealth -HealthUrl $HealthUrl
} catch {
    if (-not $deployedProcess.HasExited) {
        Stop-Process -Id $deployedProcess.Id -Force
    }
    Remove-Item $PidPath, $UrlPath -Force -ErrorAction SilentlyContinue
    throw
}

if ($deployedProcess.HasExited) {
    Remove-Item $PidPath, $UrlPath -Force -ErrorAction SilentlyContinue
    throw "Local deployment process exited unexpectedly. Check $ErrorLogPath for details."
}

Write-Host ""
Write-Host "Deploy phase completed successfully."
Write-Host "URL: $BaseUrl"
Write-Host "Docs: $BaseUrl/docs"
Write-Host "Health: $HealthUrl"
Write-Host "PID: $($deployedProcess.Id)"
Write-Host "Logs: $OutputLogPath, $ErrorLogPath"
