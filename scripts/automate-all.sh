#!/bin/bash
# scripts/automate-all.sh
# One-command automation for full RADIANT deployment and optional post-deploy setup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[AUTOMATE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

load_automation_env() {
  local env_file="${AUTOMATION_ENV_FILE:-$ROOT_DIR/.automation.env}"
  if [ -f "$env_file" ]; then
    log "Loading automation env file: $env_file"
    set -a
    # shellcheck source=/dev/null
    . "$env_file"
    set +a
  fi
}

ensure_kubectl_context() {
  if kubectl config current-context >/dev/null 2>&1; then
    return 0
  fi

  local candidates=()
  if [ -f "$HOME/.kube/config" ]; then
    candidates+=("$HOME/.kube/config")
  fi

  # WSL fallback: discover kubeconfig from Windows user profiles.
  local c
  for c in /mnt/c/Users/*/.kube/config; do
    [ -f "$c" ] && candidates+=("$c")
  done

  local cfg
  for cfg in "${candidates[@]}"; do
    if KUBECONFIG="$cfg" kubectl config current-context >/dev/null 2>&1; then
      export KUBECONFIG="$cfg"
      log "Using kubeconfig: $KUBECONFIG"
      return 0
    fi
  done

  return 1
}

ensure_traefik_crds() {
  if [ "${ENABLE_TRAEFIK_CRDS_AUTO:-true}" != "true" ]; then
    warn "ENABLE_TRAEFIK_CRDS_AUTO=false; skipping Traefik CRD bootstrap"
    return 0
  fi

  if kubectl api-resources --api-group=traefik.io 2>/dev/null | grep -q 'ingressroutes'; then
    log "Traefik CRDs already available"
    return 0
  fi

  warn "Traefik CRDs not found; applying CRD definitions"
  kubectl apply -f "https://raw.githubusercontent.com/traefik/traefik/v3.0/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml" >/dev/null 2>&1 || {
    warn "Failed to apply Traefik CRD definitions"
    return 0
  }

  kubectl apply -f "https://raw.githubusercontent.com/traefik/traefik/v3.0/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml" >/dev/null 2>&1 || {
    warn "Failed to apply Traefik CRD RBAC"
    return 0
  }

  if kubectl api-resources --api-group=traefik.io 2>/dev/null | grep -q 'ingressroutes'; then
    log "Traefik CRDs installed successfully"
  else
    warn "Traefik CRDs still unavailable; ingress routes may fail"
  fi
}

ensure_metrics_server() {
  if [ "${ENABLE_METRICS_SERVER_AUTO:-true}" != "true" ]; then
    warn "ENABLE_METRICS_SERVER_AUTO=false; skipping metrics-server bootstrap"
    return 0
  fi

  if kubectl top nodes >/dev/null 2>&1; then
    log "metrics-server already operational"
    return 0
  fi

  warn "metrics-server not ready; applying metrics-server components"
  kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml" >/dev/null 2>&1 || {
    warn "Failed to apply metrics-server manifests"
    return 0
  }

  local args
  args="$(kubectl -n kube-system get deploy metrics-server -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null || true)"
  if [[ "$args" != *"--kubelet-insecure-tls"* ]]; then
    kubectl -n kube-system patch deployment metrics-server --type='json' \
      -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1 || true
  fi

  kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s >/dev/null 2>&1 || {
    warn "metrics-server rollout not ready yet"
    return 0
  }

  if kubectl top nodes >/dev/null 2>&1; then
    log "metrics-server is operational"
  else
    warn "metrics-server installed but metrics API is not ready yet"
  fi
}

print_plan() {
  cat << 'EOF'
Automation plan:
  1. Validate toolchain and cluster access
  2. Deploy full stack (scripts/deploy-all.sh)
  3. Apply optional secret/config updates from environment variables
  4. Run health validation (scripts/health-check.sh)
  5. (Optional) run demo traffic replay

Optional environment variables:
  AUTOMATION_ENV_FILE          Path to env file (default: .automation.env)
  TRIAGE_API_KEY              Configure triage-secret and restart enrichment worker
  MISP_AUTH_KEY               Create/update misp-authkey-secret in adi namespace
  STAMUSML_API_URL            StamusML endpoint URL
  STAMUSML_API_KEY            StamusML API key
  ARKIME_API_URL              Arkime AI endpoint URL
  ARKIME_API_KEY              Arkime AI API key
  ENABLE_TRAEFIK_CRDS_AUTO    Auto-install Traefik CRDs if missing (default: true)
  ENABLE_METRICS_SERVER_AUTO  Auto-install metrics-server if missing (default: true)
  ENABLE_MISP_FEEDS=true      Run scripts/configure-misp-feeds.sh
  ENABLE_DEMO_TRAFFIC=true    Run scripts/demo-pcap-replay.sh in non-interactive mode
  DEMO_MODE=quick|slow|loop   Replay mode used when ENABLE_DEMO_TRAFFIC=true (default: quick)
  DEMO_INTERFACE=<iface>      Interface for replay (default: eth0)
EOF
}

cd "$ROOT_DIR"

load_automation_env
print_plan

log "Running pre-flight checks..."
require_cmd kubectl
require_cmd bash
ensure_kubectl_context || fail "No usable kubectl context found (set KUBECONFIG or configure kubectl context)"
kubectl cluster-info >/dev/null 2>&1 || fail "Cannot reach Kubernetes cluster"
ensure_traefik_crds
ensure_metrics_server
log "Pre-flight checks passed"

log "Deploying full stack"
bash scripts/deploy-all.sh

if [ -n "${TRIAGE_API_KEY:-}" ]; then
  log "Applying TRIAGE_API_KEY"
  bash scripts/update-triage-key.sh "$TRIAGE_API_KEY"
else
  warn "TRIAGE_API_KEY not provided; enrichment worker will keep placeholder key"
fi

if [ -n "${MISP_AUTH_KEY:-}" ]; then
  log "Applying MISP_AUTH_KEY for Suricata rules updater"
  kubectl create secret generic misp-authkey-secret \
    --namespace adi \
    --from-literal=key="$MISP_AUTH_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -
else
  warn "MISP_AUTH_KEY not provided; rules updater may fail against protected MISP API"
fi

if [ -n "${STAMUSML_API_URL:-}" ] || [ -n "${STAMUSML_API_KEY:-}" ] || [ -n "${ARKIME_API_URL:-}" ] || [ -n "${ARKIME_API_KEY:-}" ]; then
  log "Applying AI add-on endpoint/key configuration"
  bash scripts/update-ai-addon-secrets.sh \
    "${STAMUSML_API_URL:-}" \
    "${STAMUSML_API_KEY:-}" \
    "${ARKIME_API_URL:-}" \
    "${ARKIME_API_KEY:-}"
else
  warn "AI add-on endpoint variables not set; stamus/arkime workers stay in local placeholder mode"
fi

if [ "${ENABLE_MISP_FEEDS:-false}" = "true" ]; then
  log "Configuring MISP feeds"
  bash scripts/configure-misp-feeds.sh
fi

log "Running health check"
bash scripts/health-check.sh

if [ "${ENABLE_DEMO_TRAFFIC:-false}" = "true" ]; then
  log "Running demo traffic replay"
  DEMO_MODE="${DEMO_MODE:-quick}" DEMO_INTERFACE="${DEMO_INTERFACE:-eth0}" bash scripts/demo-pcap-replay.sh
fi

log "Automation complete"
echo ""
log "Next: open Kibana Discover and verify indices: radiant-suricata-v3-*"
