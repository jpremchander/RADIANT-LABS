#!/bin/bash
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}OK${NC}    $1"; }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; }
section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

section "Node Status"
kubectl get nodes -o wide

section "Pod Status"
kubectl get pods -A --sort-by=.metadata.namespace | grep -v "kube-system"

section "PVC Status"
kubectl get pvc -A | grep -v "kube-system"

section "Resource Usage"
kubectl top nodes 2>/dev/null || warn "metrics-server not ready"
kubectl top pods -A 2>/dev/null | grep -v "kube-system" || true

section "Service Endpoints"
for ns in ati adi monitoring soar ai; do
  echo "  namespace: $ns"
  kubectl get svc -n $ns 2>/dev/null | tail -n +2 | awk '{printf "    %-30s %s\n", $1, $5}'
done

section "Resource Quota Usage"
kubectl get resourcequota -A | grep -v "kube-system"

section "CronJob Status"
kubectl get cronjobs -A | grep -v "kube-system"

section "Ingress Routes"
kubectl get ingressroute -A 2>/dev/null || warn "No IngressRoutes found"

echo ""
echo -e "${GREEN}Health check complete.${NC}"
echo ""
echo "Add to Windows hosts
