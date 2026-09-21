param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 8080,
    [switch]$SkipBuild,
    [switch]$SkipNpmInstall
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

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$PythonInVenv = Resolve-FromProjectRoot ".venv\Scripts\python.exe"
$RuntimeDir = Resolve-FromProjectRoot ".runtime"
$ReportsDir = Resolve-FromProjectRoot "reports\newman"
$CollectionPath = Resolve-FromProjectRoot "postman\newman\API Testing.postman_collection.json"
$EnvironmentPath = Resolve-FromProjectRoot "postman\newman\Test Subject 1.postman_environment.json"
$BaseUrl = "http://${HostName}:$Port"
$HealthUrl = "$BaseUrl/actuator/health"
$ServerProcess = $null

Set-Location $ProjectRoot

try {
    if (-not $SkipBuild) {
        Write-Step "Running Build phase before tests"
        & (Resolve-FromProjectRoot "scripts\build.ps1")
    }

    if (-not (Test-Path $PythonInVenv)) {
        throw "Missing virtual environment Python at $PythonInVenv. Run scripts\build.ps1 first."
    }

    Write-Step "Preparing Newman dependencies"
    if (-not $SkipNpmInstall) {
        npm install
    }

    Write-Step "Generating Newman collection and environment"
    node (Resolve-FromProjectRoot "scripts\export-postman-newman.mjs")

    New-Item -ItemType Directory -Force -Path $RuntimeDir, $ReportsDir | Out-Null
    $serverOutputLogPath = Join-Path $RuntimeDir "test-server.out.log"
    $serverErrorLogPath = Join-Path $RuntimeDir "test-server.err.log"

    Write-Step "Starting temporary API server at $BaseUrl"
    $ServerProcess = Start-Process `
        -FilePath $PythonInVenv `
        -ArgumentList @("-m", "uvicorn", "main:app", "--host", $HostName, "--port", "$Port") `
        -WorkingDirectory $ProjectRoot `
        -RedirectStandardOutput $serverOutputLogPath `
        -RedirectStandardError $serverErrorLogPath `
        -PassThru `
        -WindowStyle Hidden

    Wait-ForHealth -HealthUrl $HealthUrl

    Write-Step "Running Newman tests"
    npx newman run $CollectionPath `
        -e $EnvironmentPath `
        --env-var "baseUrl=$BaseUrl" `
        --reporters cli,json,junit `
        --reporter-json-export (Join-Path $ReportsDir "newman-report.json") `
        --reporter-junit-export (Join-Path $ReportsDir "newman-report.xml")

    if ($LASTEXITCODE -ne 0) {
        throw "Newman tests failed with exit code $LASTEXITCODE."
    }

    Write-Host ""
    Write-Host "Test phase completed successfully."
    Write-Host "Reports: $ReportsDir"
} finally {
    if ($ServerProcess -and -not $ServerProcess.HasExited) {
        Write-Step "Stopping temporary API server"
        Stop-Process -Id $ServerProcess.Id -Force
        $ServerProcess.WaitForExit()
    }
}
