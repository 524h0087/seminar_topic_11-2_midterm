param(
    [string]$HostName = "127.0.0.1", # Host address the temporary test server binds to.
    [int]$Port = 8080, # Port the temporary test server listens on.
    [switch]$SkipBuild, # Skips running build.ps1 before testing.
    [switch]$SkipNpmInstall # Skips "npm install" for the Newman dependencies.
)

# Treat every error as terminating so the test phase fails fast.
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

# Project root (parent of the scripts folder).
$ProjectRoot = Split-Path -Parent $PSScriptRoot

# Python executable inside the virtual environment, used to run uvicorn.
$PythonInVenv = Resolve-FromProjectRoot ".venv\Scripts\python.exe"

# Folder holding runtime state and the test server logs.
$RuntimeDir = Resolve-FromProjectRoot ".runtime"

# Output folder for the Newman JSON and JUnit reports.
$ReportsDir = Resolve-FromProjectRoot "reports\newman"

# Generated Postman collection run by Newman.
$CollectionPath = Resolve-FromProjectRoot "postman\newman\API Testing.postman_collection.json"

# Generated Postman environment used by Newman.
$EnvironmentPath = Resolve-FromProjectRoot "postman\newman\Test Subject 1.postman_environment.json"

# Base URL of the temporary test server.
$BaseUrl = "http://${HostName}:$Port"

# Health endpoint used to confirm the test server is ready.
$HealthUrl = "$BaseUrl/actuator/health"

# Temporary uvicorn process; stopped in the finally block.
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
    # Log file for the test server's standard output.
    $serverOutputLogPath = Join-Path $RuntimeDir "test-server.out.log"

    # Log file for the test server's standard error.
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
