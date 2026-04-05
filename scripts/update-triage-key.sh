#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CREDS_FILE="$ROOT_DIR/credentials.txt"

if [ -z "$1" ]; then
  echo "Usage: bash scripts/update-triage-key.sh YOUR_TRIAGE_API_KEY"
  echo "Get your key from: https://tria.ge/account"
  exit 1
fi
TRIAGE_KEY="$1"
if [ ! -f "$CREDS_FILE" ]; then
  echo "ERROR: credentials.txt not found at $CREDS_FILE"
  echo "Run: bash scripts/generate-secrets.sh"
  exit 1
fi

MISP_KEY=$(grep 'MISP auth key' "$CREDS_FILE" | awk '{print $NF}')
if [ -z "$MISP_KEY" ]; then
  echo "ERROR: Could not read MISP auth key from credentials.txt"
  exit 1
fi

echo "Updating Triage API key..."
kubectl create secret generic triage-secret \
  --namespace ai \
  --from-literal=api-key="$TRIAGE_KEY" \
  --from-literal=misp-url="http://misp.ati.svc.cluster.local" \
  --from-literal=misp-key="$MISP_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
sed -i "s|REPLACE_WITH_YOUR_TRIAGE_KEY|$TRIAGE_KEY|g" "$CREDS_FILE"
kubectl rollout restart deployment/enrichment-worker -n ai
echo "Done. Watch: kubectl logs -f deployment/enrichment-worker -n ai"
