# Project RADIANT - SECU8090 Assignment 2 (Group 1)

AI-enhanced open-source Threat Intelligence (ATI) + Threat Detection/Analytics (ADI) Proof of Concept for:

- Course: `SECU8090 Advanced Topics in Cybersecurity Response Planning`
- Term: `Winter 2026 - Section 1`
- Team: `Group 1`

This repository deploys an end-to-end pipeline:

`MISP (ATI) -> Suricata (ADI) -> AI enrichment + automated rule updates -> Kibana/Grafana/Shuffle analyst workflow`

## 1. Assignment Objective Coverage

- Design and deploy ATI + ADI stack: `Implemented`
- AI add-ons (minimum 2): `Implemented/Planned`
- Validate detections with replayed dataset: `Implemented`
- Demonstrate analyst workflow and incident lifecycle: `Implemented`

### AI Add-ons Status

| AI Add-on (Assignment List) | Status in this repo | Notes |
|---|---|---|
| Hatching Triage (Automated Malware Analysis) | Implemented | `ai/enrichment/enrichment.yaml` submits suspicious URLs and enriches MISP events with Triage verdict/report link. |
| Deep Learning Suricata Rule Generator | Implemented as automated rule generation pipeline | `adi/suricata/rules-updater-cronjob.yaml` converts fresh MISP IOCs to Suricata rules every 15 minutes and hot-reloads rules. |
| JoeSandbox ML Classification | Optional extension | Not yet deployed in manifests. |
| Intezer Analyze (AI Code DNA) | Optional extension | Not yet deployed in manifests. |
| StamusML for Suricata | Optional extension | Not yet deployed in manifests. |
| Arkime AI PCAP Tagging | Optional extension | Not yet deployed in manifests. |

## 2. Lab Topology (Conestoga vSphere)

### Core hosts

| System | Role | IP |
|---|---|---|
| Ubuntu Server 24 (k3s node) | MISP + Suricata + Elastic + AI workers | `192.168.10.90` |
| pfSense | LAN gateway / containment point | `LAN: 192.168.10.10`, `WAN: 10.180.53.0` |
| Windows Server | Analyst workstation for dashboards/UI | `192.168.10.100` |

### Network model

- Internal lab segment: `192.168.10.0/24`
- Suricata HOME_NET: `192.168.10.0/24`
- No production connectivity for test traffic

## 3. Stack Components

| Component | Namespace | Purpose |
|---|---|---|
| MISP | `ati` | Threat Intelligence Platform |
| MySQL 8.4 | `ati` | MISP database |
| Redis 7.4 | `ati` | MISP cache/session backend |
| Suricata | `adi` | IDS/NDR detection engine |
| Filebeat | `adi` | Ships Suricata EVE logs to Elasticsearch |
| Rules Updater CronJob | `adi` | Pulls MISP IOCs and generates Suricata rules |
| Enrichment Worker (Python) | `ai` | Sends suspicious URLs to Hatching Triage and enriches MISP |
| Elasticsearch | `monitoring` | Event storage and search |
| Kibana | `monitoring` | SOC analyst dashboard and detections |
| Prometheus + Grafana | `monitoring` | Infra/service monitoring |
| Shuffle SOAR | `soar` | Alert-driven response playbooks |

## 4. Environment Fit and Dependencies

### Supported platform

- OS: `Ubuntu 24.04 Server`
- Virtualization: `VMware vSphere`
- Orchestrator: `k3s v1.34+` (single-node)

### Recommended minimum resources

- vCPU: `8`
- RAM: `16 GB` (24 GB preferred for smoother Elastic/Kibana)
- Storage: `120 GB` (fast local disk recommended)

### Required network and ports

- Node ingress: `80/tcp` (Traefik HTTP entrypoint)
- Kubernetes API/internal traffic as required by k3s
- Internal service ports (cluster local):
	- MySQL `3306`
	- Redis `6379`
	- Elasticsearch `9200`
	- Kibana `5601`
	- Shuffle frontend/backend `3001/5001`

### External dependencies

- MISP threat feeds (Abuse.ch, ThreatFox, Feodo, etc.)
- Hatching Triage API key (`TRIAGE_API_KEY`)
- MISP API auth key for rules updater (`misp-authkey-secret`)

### Data/telemetry sources

- Suricata EVE JSON (`alert`, `http`, `dns`, `flow`, etc.)
- Replayed PCAP from `scripts/demo-pcap-replay.sh`
- MISP indicators (domains, IPs, URLs)

### Security/privacy constraints

- Use only lab-safe/simulated traffic and controlled IOC testing
- Do not connect detection pipeline to production networks
- Keep API keys out of Git (`credentials.txt` must never be committed)
- Follow college policy for malware sample handling and export restrictions

## 5. Architecture and Data Flow

1. Threat intel is ingested into `MISP` (feeds + manual/event IOCs).
2. `rules-updater` CronJob pulls recent MISP IOCs and generates Suricata rules.
3. `Suricata` inspects traffic on `ens33` and emits EVE alerts.
4. `Filebeat` ships events to `Elasticsearch`.
5. `Kibana` visualizes detections for analyst triage.
6. `AI enrichment worker` polls alert events, submits suspicious URLs to Hatching Triage, then writes enriched events/tags back to MISP.
7. `Shuffle` playbook can execute response actions (for example, temporary pfSense block) and support containment workflow.

## 6. Deployment

### 6.1 Prerequisites

- `kubectl` configured against the k3s cluster on `192.168.10.90`
- `local-path` StorageClass available
- Internet egress for pulling container images and threat feeds

### 6.2 Quick deploy

```bash
chmod +x scripts/*.sh
bash scripts/deploy-all.sh
```

This deploy script applies resources in dependency order:

1. Namespaces and quotas
2. Secrets generation
3. MySQL and Redis
4. MISP
5. Elasticsearch, Kibana, Prometheus, Grafana
6. Suricata, Filebeat, rules updater
7. AI enrichment worker
8. Shuffle and ingress routes

## 7. Post-Deploy Setup

### 7.1 Windows Server access (`192.168.10.100`)

Add to `C:\Windows\System32\drivers\etc\hosts`:

```text
192.168.10.90  misp.lab kibana.lab shuffle.lab grafana.lab
```

Open:

- MISP: `http://misp.lab`
- Kibana: `http://kibana.lab`
- Shuffle: `http://shuffle.lab`
- Grafana: `http://grafana.lab`

### 7.2 Configure threat feeds

```bash
bash scripts/configure-misp-feeds.sh
```

### 7.3 Configure Hatching Triage API key

```bash
bash scripts/update-triage-key.sh YOUR_TRIAGE_API_KEY
```

### 7.4 Configure MISP auth key for rule generation

```bash
kubectl create secret generic misp-authkey-secret \
	-n adi \
	--from-literal=key=YOUR_MISP_AUTH_KEY
```

## 8. PoC Validation

### 8.1 Generate replay traffic

```bash
bash scripts/demo-pcap-replay.sh
```

### 8.2 Verify Suricata detections

- Kibana -> Discover -> `suricata-*`
- Filter: `event_type : "alert"`

### 8.3 Verify AI enrichment value

- Check worker logs:

```bash
kubectl logs -f deployment/enrichment-worker -n ai
```

- Confirm Triage submission/report IDs in logs.
- Confirm enriched events in MISP include tags/comments/triage URL.

### 8.4 Verify IOC-to-rule automation

- Confirm rules job runs every 15 min:

```bash
kubectl get cronjob suricata-rules-updater -n adi
kubectl logs job/<latest-job-name> -n adi
```

- Confirm dynamic rules present in `suricata-rules` ConfigMap.

## 9. Demonstration Script (15-20 minutes)

1. Show architecture slide and lab topology (vSphere, pfSense, Ubuntu node, Windows analyst host).
2. Show ATI ingest in MISP (feeds enabled, sample IOCs, tags/galaxies).
3. Replay dataset (`demo-pcap-replay.sh`) and show Suricata alerts in Kibana.
4. Show AI add-on 1 (Hatching Triage): alert -> sandbox submission -> enriched MISP event.
5. Show AI add-on 2 (automated Suricata rule generation from fresh MISP IOCs).
6. Trigger/observe Shuffle response workflow and explain SOC operations:
	 - Triage analyst validates
	 - Incident responder escalates
	 - Containment via firewall action
7. Walk one incident through:
	 - Detection -> Containment -> Eradication -> Recovery
8. Close with measured AI value (for example: faster triage time, better context, improved detection coverage).

## 10. Assignment Deliverables Checklist

- [ ] 15-20 minute recorded presentation (all team members visible)
- [ ] Slide deck (architecture, screenshots, data flows, AI outputs)
- [ ] Meeting minutes (minimum twice per week)
- [ ] Updated WBS
- [ ] Configuration notes and runbook (this repo + `docs/runbook.md`)
- [ ] Incident walkthrough evidence (screenshots/log snippets)

## 11. Operations and Troubleshooting

Useful commands:

```bash
kubectl get pods -A
kubectl logs -f deployment/misp -n ati
kubectl logs -f daemonset/suricata -n adi
kubectl logs -f deployment/enrichment-worker -n ai
kubectl get events -A --sort-by=.lastTimestamp
```

Common issues:

- MISP startup delay: first boot can take several minutes.
- Elasticsearch memory pressure: reduce heap in `monitoring/elasticsearch/elasticsearch.yaml`.
- No Suricata traffic: confirm monitored interface is `ens33` and traffic replay path is correct.
- AI worker not enriching: verify `triage-secret` and outbound access to `tria.ge`.

## 12. Governance and Academic Integrity

- Maintain twice-weekly team minutes and weekly instructor checkpoints.
- Use only authorized lab datasets and controlled simulations.
- Cite all external tools/feeds/sources used in slides and report.
- Keep all submitted work original to Group 1.