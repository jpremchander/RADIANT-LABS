Project RADIANT — K8s Deployment
AI-enhanced Threat Intelligence and Detection stack deployed on k3s.
Stack
ComponentNamespacePurposeMISPatiThreat Intelligence PlatformMySQL 8.4atiMISP databaseRedis 7.4atiMISP cacheSuricataadiIDS / Network DetectionFilebeatadiLog shipping to ElasticsearchHatching Triage workeraiAI malware sandbox enrichmentMISP ATT&CK taggeraiAuto MITRE ATT&CK taggingElasticsearchmonitoringSIEM event storeKibanamonitoringAnalyst dashboardPrometheusmonitoringMetricsGrafanamonitoringOperations dashboardShuffle SOARsoarAutomated IR playbooks
Environment

Ubuntu 24.04 Server on VMware vSphere
k3s v1.34+ single-node cluster
IP: 192.168.10.90
Gateway: 192.168.10.10

Deploy Order

Namespaces + quotas
Secrets
MySQL → Redis (ati)
MISP (ati)
Suricata + Filebeat (adi)
Elasticsearch → Kibana (monitoring)
Prometheus + Grafana (monitoring)
Enrichment worker + ATT&CK tagger (ai)
Shuffle SOAR (soar)
Ingress routes

Quick deploy
bashchmod +x scripts/deploy-all.sh
./scripts/deploy-all.sh
Credentials
All secrets are generated at deploy time by scripts/generate-secrets.sh.
Never commit credentials.txt to git.
Network access (from Windows 11 at 192.168.10.x)
Add to Windows hosts file (C:\Windows\System32\drivers\etc\hosts):
192.168.10.90  misp.lab kibana.lab shuffle.lab grafana.lab
Then access via browser:

MISP:    http://misp.lab
Kibana:  http://kibana.lab
Shuffle: http://shuffle.lab
Grafana: http://grafana.lab