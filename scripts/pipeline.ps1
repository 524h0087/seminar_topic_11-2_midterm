param(
    [string]$HostName = "127.0.0.1", # Host address the local API binds to.
    [int]$Port = 8080, # Port the local API listens on.
    [string]$NgrokUrl = $env:NGROK_PUBLIC_URL, # Public ngrok URL to verify; defaults to the NGROK_PUBLIC_URL env var.
    [switch]$SkipNpmInstall, # Passed to test.ps1 to skip "npm install".
    [switch]$KeepExistingDeployment, # Skips stopping the current local deployment before the run.
    [switch]$SkipNgrokVerification # Skips the ngrok public tunnel health check.
)

# Treat every error as terminating so the pipeline fails fast.
$ErrorActionPreference = "Stop"

# Prints a blank line followed by a "==> <message>" step header.
function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

# Runs one pipeline phase under a step header; throws if it ends with a non-zero exit code.
function Invoke-Phase {
    param(
        [string]$Name, # Phase name shown in the header and error message.
        [scriptblock]$Command # Script block that performs the phase.
    )

    Write-Step $Name
    & $Command

    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

# Trims whitespace and any trailing "/" from a URL; returns $null when empty.
function Format-BaseUrl {
    param([string]$Url)

    if (-not $Url) {
        return $null
    }

    return $Url.Trim().TrimEnd("/")
}

# Polls the health endpoint until it reports status "UP" and returns the response;
# throws with the last error seen after the timeout.
function Wait-ForHealth {
    param(
        [string]$HealthUrl, # Health endpoint to poll.
        [hashtable]$Headers = @{}, # Extra request headers (e.g. to bypass the ngrok warning page).
        [int]$TimeoutSeconds = 30 # Maximum time to wait before failing.
    )

    # Point in time after which polling gives up.
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    # Most recent failure reason, reported if the check times out.
    $lastError = $null

    do {
        try {
            $response = Invoke-RestMethod -Uri $HealthUrl -Headers $Headers -TimeoutSec 5
            if ($response.status -eq "UP") {
                return $response
            }

            $lastError = "Unexpected health response from $HealthUrl"
        } catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds 750
        }
    } while ((Get-Date) -lt $deadline)

    throw "Health check failed at $HealthUrl within $TimeoutSeconds seconds. Last error: $lastError"
}

# Writes the pipeline result summary (phase statuses and URLs) to a text file.
function Write-PipelineSummary {
    param(
        [string]$Path, # Destination file for the summary.
        [string]$LocalUrl, # Local API base URL.
        [string]$NgrokUrl, # Public ngrok base URL, if any.
        [bool]$NgrokVerified # Whether the ngrok health check passed.
    )

    # Summary lines written to the file.
    $lines = @(
        "Local Automation Pipeline Summary",
        "GeneratedAt: $((Get-Date).ToString('s'))",
        "Build: passed",
        "Test: passed",
        "Deploy: passed",
        "Local Health: passed",
        "Local API: $LocalUrl",
        "Local Docs: $LocalUrl/docs"
    )

    if ($NgrokVerified) {
        $lines += @(
            "ngrok Health: passed",
            "Public API: $NgrokUrl",
            "Public Docs: $NgrokUrl/docs"
        )
    } elseif ($SkipNgrokVerification) {
        $lines += "ngrok Health: skipped"
    } else {
        $lines += "ngrok Health: not configured"
    }

    Set-Content -Path $Path -Value $lines
}

# Project root (parent of the scripts folder).
$ProjectRoot = Split-Path -Parent $PSScriptRoot # seminar_topic_11-2_midterm/

# Folder holding runtime state and the pipeline summary.
$RuntimeDir = Join-Path $ProjectRoot ".runtime" # seminar_topic_11-2_midterm/.runtime

# File the pipeline summary is written to.
$SummaryPath = Join-Path $RuntimeDir "pipeline-summary.txt" # seminar_topic_11-2_midterm/.runtime/pipeline-summary.txt

# Base URL of the local API.
$LocalUrl = "http://${HostName}:$Port" # http://127.0.0.1:8080

# Health endpoint of the local API.
$LocalHealthUrl = "$LocalUrl/actuator/health" # http://127.0.0.1:8080/actuator/health

# ngrok URL with whitespace and trailing "/" removed ($null if not configured).
$NgrokUrl = Format-BaseUrl $NgrokUrl

# Set to $true once the ngrok tunnel health check passes.
$NgrokVerified = $false

Set-Location $ProjectRoot
New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

if (-not $KeepExistingDeployment) {
    Invoke-Phase "Stopping any existing local deployment before pipeline run" {
        & (Join-Path $ProjectRoot "scripts\stop-local.ps1") -Quiet
    }
}

Invoke-Phase "Running Build phase" {
    & (Join-Path $ProjectRoot "scripts\build.ps1")
}

Invoke-Phase "Running Test phase" {
    if ($SkipNpmInstall) {
        & (Join-Path $ProjectRoot "scripts\test.ps1") -HostName $HostName -Port $Port -SkipBuild -SkipNpmInstall
    } else {
        & (Join-Path $ProjectRoot "scripts\test.ps1") -HostName $HostName -Port $Port -SkipBuild
    }
}

Invoke-Phase "Running Deploy phase" {
    & (Join-Path $ProjectRoot "scripts\deploy-local.ps1") -HostName $HostName -Port $Port -SkipBuild
}

Invoke-Phase "Verifying local deployment health" {
    Wait-ForHealth -HealthUrl $LocalHealthUrl | Out-Null
}

if ($SkipNgrokVerification) {
    Write-Step "Skipping ngrok public tunnel verification"
} elseif ($NgrokUrl) {
    Invoke-Phase "Verifying ngrok public tunnel health" {
        # Header that skips ngrok's browser warning page so the JSON response is returned.
        $headers = @{
            "ngrok-skip-browser-warning" = "true"
        }
        Wait-ForHealth -HealthUrl "$NgrokUrl/actuator/health" -Headers $headers | Out-Null
    }
    $NgrokVerified = $true
} else {
    Write-Step "No ngrok URL configured; public tunnel verification was not run"
}

Write-PipelineSummary -Path $SummaryPath -LocalUrl $LocalUrl -NgrokUrl $NgrokUrl -NgrokVerified $NgrokVerified

Write-Host ""
Write-Host "Pipeline completed successfully."
Write-Host "Build: passed"
Write-Host "Test: passed"
Write-Host "Deploy: passed"
Write-Host "Local Health: passed"
if ($NgrokVerified) {
    Write-Host "ngrok Health: passed"
    Write-Host "Public API: $NgrokUrl"
    Write-Host "Public Docs: $NgrokUrl/docs"
} elseif ($SkipNgrokVerification) {
    Write-Host "ngrok Health: skipped"
} else {
    Write-Host "ngrok Health: not configured"
}
Write-Host "Local API: $LocalUrl"
Write-Host "Local Docs: $LocalUrl/docs"
Write-Host "Summary: $SummaryPath"
