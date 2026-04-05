$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$stateDir = Join-Path $root ".portforwards"
$stateFile = Join-Path $stateDir "portforwards.json"

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null

$forwards = @(
    @{ Name = "misp"; Namespace = "ati"; Service = "misp"; LocalPort = 18443; RemotePort = 443 },
    @{ Name = "kibana"; Namespace = "monitoring"; Service = "kibana"; LocalPort = 15601; RemotePort = 5601 },
    @{ Name = "grafana"; Namespace = "monitoring"; Service = "grafana"; LocalPort = 13000; RemotePort = 3000 },
    @{ Name = "prometheus"; Namespace = "monitoring"; Service = "prometheus"; LocalPort = 19090; RemotePort = 9090 },
    @{ Name = "shuffle"; Namespace = "soar"; Service = "shuffle"; LocalPort = 13001; RemotePort = 3001 }
)

$running = @()

foreach ($f in $forwards) {
    $cmd = "kubectl -n $($f.Namespace) port-forward svc/$($f.Service) $($f.LocalPort):$($f.RemotePort)"

    # Kill any old process bound to this local port so restarts are idempotent.
    $conn = Get-NetTCPConnection -LocalPort $f.LocalPort -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        foreach ($c in $conn) {
            try { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    $proc = Start-Process -FilePath "powershell" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", $cmd
    ) -WindowStyle Hidden -PassThru

    $running += [PSCustomObject]@{
        Name = $f.Name
        Namespace = $f.Namespace
        Service = $f.Service
        LocalPort = $f.LocalPort
        RemotePort = $f.RemotePort
        Pid = $proc.Id
    }
}

$running | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile -Encoding UTF8

Write-Host "Local access tunnels started:"
$running | Format-Table Name, LocalPort, Namespace, Service, Pid -AutoSize
Write-Host ""
Write-Host "Open in browser:"
Write-Host "- MISP:       https://127.0.0.1:18443/users/login"
Write-Host "- Kibana:     http://127.0.0.1:15601"
Write-Host "- Grafana:    http://127.0.0.1:13000"
Write-Host "- Prometheus: http://127.0.0.1:19090"
Write-Host "- Shuffle:    http://127.0.0.1:13001"
