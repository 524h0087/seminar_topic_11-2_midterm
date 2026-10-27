param(
    [string]$NgrokUrl = $env:NGROK_PUBLIC_URL, # Public ngrok URL to verify; defaults to the NGROK_PUBLIC_URL env var.
    [string]$HealthPath = "/actuator/health", # Health endpoint path appended to the ngrok URL.
    [int]$TimeoutSeconds = 30 # Maximum time to wait for the tunnel to report healthy.
)

# Treat every error as terminating so verification fails fast.
$ErrorActionPreference = "Stop"

# Prints a blank line followed by a "==> <message>" step header.
function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

# Trims whitespace and any trailing "/" from a URL; returns $null when empty.
function Format-BaseUrl {
    param([string]$Url)

    if (-not $Url) {
        return $null
    }

    return $Url.Trim().TrimEnd("/")
}

# Joins a base URL and a path with exactly one "/" between them.
function Join-UrlPath {
    param(
        [string]$BaseUrl, # Base URL without a trailing "/".
        [string]$Path # Path to append; a leading "/" is optional.
    )

    return "$BaseUrl/$($Path.TrimStart('/'))"
}

# Polls the ngrok health endpoint until it reports status "UP" and returns the response;
# throws with the last error seen after the timeout.
function Wait-ForNgrokHealth {
    param(
        [string]$Url, # Full public health endpoint URL.
        [int]$TimeoutSeconds # Maximum time to wait before failing.
    )

    # Header that skips ngrok's browser warning page so the JSON response is returned.
    $headers = @{
        "ngrok-skip-browser-warning" = "true"
    }

    # Point in time after which polling gives up.
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    # Most recent failure reason, reported if the check times out.
    $lastError = $null

    do {
        try {
            $response = Invoke-RestMethod -Uri $Url -Headers $headers -TimeoutSec 5
            if ($response.status -eq "UP") {
                return $response
            }

            $lastError = "Unexpected health response from $Url"
        } catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds 750
        }
    } while ((Get-Date) -lt $deadline)

    throw "ngrok health check failed at $Url within $TimeoutSeconds seconds. Last error: $lastError"
}

# ngrok URL with whitespace and trailing "/" removed ($null if not configured).
$NgrokUrl = Format-BaseUrl $NgrokUrl
if (-not $NgrokUrl) {
    throw "Missing ngrok URL. Pass -NgrokUrl or set NGROK_PUBLIC_URL."
}

# Full public health endpoint URL.
$HealthUrl = Join-UrlPath -BaseUrl $NgrokUrl -Path $HealthPath # https://<subdomain>.ngrok-free.app/actuator/health

Write-Step "Verifying ngrok public health endpoint"
# Health response returned once the tunnel reports "UP".
$health = Wait-ForNgrokHealth -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds

Write-Host ""
Write-Host "ngrok verification passed."
Write-Host "Public API: $NgrokUrl"
Write-Host "Public Docs: $NgrokUrl/docs"
Write-Host "Public Health: $HealthUrl"
Write-Host "Health Status: $($health.status)"
