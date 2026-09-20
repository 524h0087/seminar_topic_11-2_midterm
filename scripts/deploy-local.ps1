param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 8080,
    [switch]$SkipBuild,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

function Resolve-FromProjectRoot {
    param([string]$Path)
    Join-Path $ProjectRoot $Path
}

function Wait-ForHealth {
    param(
        [string]$HealthUrl,
        [int]$TimeoutSeconds = 30
    )

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

function Get-RecordedProcess {
    if (-not (Test-Path $PidPath)) {
        return $null
    }

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

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$PythonInVenv = Resolve-FromProjectRoot ".venv\Scripts\python.exe"
$RuntimeDir = Resolve-FromProjectRoot ".runtime"
$PidPath = Join-Path $RuntimeDir "api.pid"
$UrlPath = Join-Path $RuntimeDir "api.url"
$OutputLogPath = Join-Path $RuntimeDir "api.out.log"
$ErrorLogPath = Join-Path $RuntimeDir "api.err.log"
$BaseUrl = "http://${HostName}:$Port"
$HealthUrl = "$BaseUrl/actuator/health"

Set-Location $ProjectRoot

if ($Force) {
    Write-Step "Stopping previous local deployment if it exists"
    & (Resolve-FromProjectRoot "scripts\stop-local.ps1")
}

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
