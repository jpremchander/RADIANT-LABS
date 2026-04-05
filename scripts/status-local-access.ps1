$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$stateDir = Join-Path $root ".portforwards"
$stateFile = Join-Path $stateDir "portforwards.json"

if (-not (Test-Path $stateFile)) {
    Write-Host "No running tunnel state found."
    exit 0
}

$entries = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
$status = @()

foreach ($e in $entries) {
    $proc = Get-Process -Id $e.Pid -ErrorAction SilentlyContinue
    $listening = Get-NetTCPConnection -LocalPort $e.LocalPort -State Listen -ErrorAction SilentlyContinue
    $status += [PSCustomObject]@{
        Name = $e.Name
        LocalPort = $e.LocalPort
        Pid = $e.Pid
        ProcessAlive = [bool]$proc
        Listening = [bool]$listening
    }
}

$status | Format-Table Name, LocalPort, Pid, ProcessAlive, Listening -AutoSize
