$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$stateDir = Join-Path $root ".portforwards"
$stateFile = Join-Path $stateDir "portforwards.json"

if (-not (Test-Path $stateFile)) {
    Write-Host "No port-forward state file found at $stateFile"
    exit 0
}

$entries = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
foreach ($e in $entries) {
    try {
        Stop-Process -Id $e.Pid -Force -ErrorAction Stop
        Write-Host "Stopped $($e.Name) (PID $($e.Pid))"
    } catch {
        Write-Host "PID $($e.Pid) already stopped or inaccessible"
    }
}

Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
Write-Host "Local access tunnels stopped."
