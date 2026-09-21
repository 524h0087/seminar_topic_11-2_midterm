param(
    [string]$PythonExe = "python",
    [string]$VenvPath = ".venv",
    [switch]$SkipDependencyInstall
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

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RequirementsPath = Resolve-FromProjectRoot "requirements.txt"
$VenvFullPath = Resolve-FromProjectRoot $VenvPath
$PythonInVenv = Join-Path $VenvFullPath "Scripts\python.exe"

Set-Location $ProjectRoot

Write-Step "Validating build inputs"
if (-not (Test-Path $RequirementsPath)) {
    throw "Missing requirements.txt at $RequirementsPath"
}

Write-Step "Checking Python interpreter"
try {
    & $PythonExe --version
} catch {
    throw "Python executable '$PythonExe' was not found. Install Python or pass -PythonExe with a valid path."
}

if (-not (Test-Path $PythonInVenv)) {
    Write-Step "Creating virtual environment at $VenvFullPath"
    & $PythonExe -m venv $VenvFullPath
} else {
    Write-Step "Reusing existing virtual environment at $VenvFullPath"
}

Write-Step "Upgrading pip"
& $PythonInVenv -m pip install --upgrade pip

if ($SkipDependencyInstall) {
    Write-Step "Skipping dependency installation"
} else {
    Write-Step "Installing dependencies from requirements.txt"
    & $PythonInVenv -m pip install -r $RequirementsPath
}

Write-Step "Verifying application import"
& $PythonInVenv -c "import main; assert main.app.title == 'Student Management API'; print('FastAPI app import OK')"

Write-Step "Checking dependency consistency"
& $PythonInVenv -m pip check

Write-Host ""
Write-Host "Build phase completed successfully."
Write-Host "Virtual environment: $VenvFullPath"
