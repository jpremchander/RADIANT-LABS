#!/bin/bash
# scripts/deploy-all.sh
# Deploys the complete RADIANT stack in dependency order.
# Run from the root of the radiant-k8s directory.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[RADIANT]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

wait_for_pod() {
  local ns=$1
  local selector=$2
  local timeout=${3:-300}
  log "Waiting for pods in $ns with selector $selector (timeout: ${timeout}s)..."
  kubectl wait pod \
    --namespace "$ns" \
    --selector "$selector" \
    --for=condition=Ready \
    --timeout="${timeout}s" || fail "Pod did not become ready: $ns/$selector"
}

cd "$ROOT_DIR"

log "=== RADIANT Stack Deployment ==="
echo ""

# Pre-flight checks
log "Pre-flight checks..."
kubectl cluster-info > /dev/null 2>&1 || fail "Cannot connect to Kubernetes cluster"
kubectl get storageclass local-path > /dev/null 2>&1 || fail "local-path StorageClass not found"
if [ ! -f credentials.txt ]; then
  warn "credentials.txt not found; it will be created in Step 2"
fi
log "Pre-flight: OK"
echo ""

# Step 1: Namespaces + Quotas
log "Step 1/10: Namespaces and resource quotas..."
kubectl apply -f 00-namespaces.yaml
echo ""

# Step 2: Secrets
log "Step 2/10: Generating secrets..."
bash scripts/generate-secrets.sh
echo ""

# Step 3: MySQL
log "Step 3/10: Deploying MySQL 8.4 (StatefulSet)..."
kubectl apply -f ati/mysql/mysql.yaml
wait_for_pod ati "app=mysql" 300
log "MySQL: Ready"
echo ""

# Step 4: Redis
log "Step 4/10: Deploying Redis 7.4..."
kubectl apply -f ati/redis/redis.yaml
wait_for_pod ati "app=redis" 120
log "Redis: Ready"
echo ""

# Step 5: MISP
log "Step 5/10: Deploying MISP (this takes 3-5 minutes)..."
kubectl apply -f ati/misp/misp.yaml
wait_for_pod ati "app=misp" 600
log "MISP: Ready"
echo ""

# Step 6: Elasticsearch
log "Step 6/10: Deploying Elasticsearch 8.13..."
kubectl apply -f monitoring/elasticsearch/elasticsearch.yaml
wait_for_pod monitoring "app=elasticsearch" 300
log "Elasticsearch: Ready"
echo ""

# Step 7: Kibana + Prometheus + Grafana
log "Step 7/10: Deploying Kibana, Prometheus, Grafana..."
kubectl apply -f monitoring/kibana/kibana.yaml
kubectl apply -f monitoring/prometheus-grafana/prometheus-grafana.yaml
wait_for_pod monitoring "app=kibana" 300
wait_for_pod monitoring "app=grafana" 180
log "Monitoring stack: Ready"
echo ""

# Step 8: Suricata + Filebeat
log "Step 8/10: Deploying Suricata + Filebeat (DaemonSets)..."
kubectl apply -f adi/suricata/suricata.yaml
kubectl apply -f adi/filebeat/filebeat.yaml
kubectl apply -f adi/suricata/rules-updater-cronjob.yaml
wait_for_pod adi "app=suricata" 180
wait_for_pod adi "app=filebeat" 120
log "ADI stack: Ready"
echo ""

# Step 9: AI add-ons (modular)
log "Step 9/10: Deploying AI add-ons (Enrichment + StamusML + Arkime AI)..."
kubectl apply -k ai
kubectl rollout status deployment/enrichment-worker -n ai --timeout=180s || warn "enrichment-worker rollout delayed"
kubectl rollout status deployment/stamusml-worker -n ai --timeout=180s || warn "stamusml-worker rollout delayed"
kubectl rollout status deployment/arkime-ai-worker -n ai --timeout=180s || warn "arkime-ai-worker rollout delayed"
log "AI add-ons: Deployed"
echo ""

# Step 10: Shuffle SOAR
log "Step 10/10: Deploying Shuffle SOAR..."
kubectl apply -f soar/shuffle/shuffle.yaml
wait_for_pod soar "app=shuffle-frontend" 300
log "Shuffle SOAR: Ready"
echo ""

# Ingress routes (requires Traefik - reinstall k3s with Traefik if needed)
log "Applying ingress routes..."
kubectl apply -f ingress-routes.yaml || warn "Ingress routes failed - install Traefik first"
echo ""

# Final status
log "=== Deployment Complete ==="
echo ""
kubectl get pods -A | grep -v "kube-system"
echo ""
log "Access from Windows 11 (add to C:\\Windows\\System32\\drivers\\etc\\hosts):"
echo "  192.168.10.90  misp.lab kibana.lab shuffle.lab grafana.lab"
echo ""
log "URLs:"
echo "  MISP:    http://misp.lab     (admin@radiant.lab / see credentials.txt)"
echo "  Kibana:  http://kibana.lab"
echo "  Shuffle: http://shuffle.lab"
echo "  Grafana: http://grafana.lab  (admin / radiant-grafana)"
echo ""
warn "Next steps:"
echo "  1. Open credentials.txt and note your MISP admin password"
echo "  2. Log into MISP and get your API auth key"
echo "  3. Add your Triage API key: bash scripts/update-triage-key.sh YOUR_KEY"
echo "  4. (Optional) Configure StamusML/Arkime endpoints: bash scripts/update-ai-addon-secrets.sh STAMUSML_API_URL STAMUSML_API_KEY ARKIME_API_URL ARKIME_API_KEY"
echo "  5. Configure MISP feeds: bash scripts/configure-misp-feeds.sh"
