#!/bin/bash
set -e
if [ -z "$1" ]; then
  echo "Usage: bash scripts/update-triage-key.sh YOUR_TRIAGE_API_KEY"
  echo "Get your key from: https://tria.ge/account"
  exit 1
fi
TRIAGE_KEY="$1"
echo "Updating Triage API key..."
kubectl create secret generic triage-secret \
  --namespace ai \
  --from-literal=api-key="$TRIAGE_KEY" \
  --from-literal=misp-url="http://misp.ati.svc.cluster.local" \
  --from-literal=misp-key="$(grep 'MISP auth key' credentials.txt | awk '{print $NF}')" \
  --dry-run=client -o yaml | kubectl apply -f -
sed -i "s|REPLACE_WITH_YOUR_TRIAGE_KEY|$TRIAGE_KEY|g" credentials.txt
kubectl rollout restart deployment/enrichment-worker -n ai
echo "Done. Watch: kubectl logs -f deployment/enrichment-worker -n ai"
