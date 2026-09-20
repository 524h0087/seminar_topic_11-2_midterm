param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 8080,
    [switch]$SkipNpmInstall,
    [switch]$KeepExistingDeployment
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

function Invoke-Phase {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Step $Name
    & $Command

    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

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

Write-Host ""
Write-Host "Pipeline completed successfully."
Write-Host "Build: passed"
Write-Host "Test: passed"
Write-Host "Deploy: passed"
Write-Host "URL: http://${HostName}:$Port"
Write-Host "Docs: http://${HostName}:$Port/docs"
