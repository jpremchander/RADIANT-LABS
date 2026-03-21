# RADIANT Runbook

## Environment
| Item | Value |
|---|---|
| Ubuntu IP | 192.168.10.90 |
| Gateway / pfSense | 192.168.10.10 |
| Kubernetes | k3s v1.34+ single-node |
| Node name | radiant-node |

## Reproduce from scratch
```bash
git clone https://github.com/YOUR_USERNAME/RADIANT-LABS.git
cd RADIANT-LABS
chmod +x scripts/*.sh
bash scripts/generate-secrets.sh
bash scripts/deploy-all.sh
```

## Traefik install
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add traefik https://traefik.github.io/charts && helm repo update
kubectl create namespace traefik
helm install traefik traefik/traefik --namespace traefik \
  --set ports.web.nodePort=80 --set service.type=NodePort
kubectl apply -f ingress-routes.yaml
```

## Windows 11 hosts file
Add to `C:\Windows\System32\drivers\etc\hosts`:
```
192.168.10.90  misp.lab kibana.lab shuffle.lab grafana.lab
```

## Default credentials
| Service | URL | User | Password |
|---|---|---|---|
| MISP | http://misp.lab | admin@radiant.lab | see credentials.txt |
| Kibana | http://kibana.lab | none | - |
| Grafana | http://grafana.lab | admin | radiant-grafana |
| Shuffle | http://shuffle.lab | set on first login | - |

## Common commands
```bash
kubectl get pods -A
kubectl logs -f deployment/misp -n ati
kubectl logs -f daemonset/suricata -n adi
kubectl logs -f deployment/enrichment-worker -n ai
kubectl exec -it mysql-0 -n ati -- bash
kubectl get events -n ati --sort-by=.lastTimestamp
kubectl top pods -A
```

## Troubleshooting
- Pod Pending: `kubectl describe pod <name> -n <ns>` — check memory/PVC
- MySQL down: `kubectl logs mysql-0 -n ati`
- ES OOM: reduce heap in elasticsearch.yaml to `-Xms768m -Xmx768m`
- Suricata no traffic: confirm `hostNetwork: true` and interface is `ens33`
- MISP slow start: normal, wait 5 min on first boot

## Demo sequence
1. Split screen: Kibana | Shuffle | MISP
2. `bash scripts/demo-pcap-replay.sh`
3. Suricata alerts appear in Kibana (~30s)
4. Shuffle playbook triggers automatically
5. Show pfSense block rule added
6. Show MISP event with IOCs + ATT&CK tags
7. After 5 min: block removed, event resolved
