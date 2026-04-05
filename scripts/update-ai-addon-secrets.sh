#!/bin/bash
set -e

if [ "$#" -lt 4 ]; then
  echo "Usage: bash scripts/update-ai-addon-secrets.sh STAMUSML_API_URL STAMUSML_API_KEY ARKIME_API_URL ARKIME_API_KEY"
  echo "Use empty string for values you don't have yet."
  exit 1
fi

STAMUSML_API_URL="$1"
STAMUSML_API_KEY="$2"
ARKIME_API_URL="$3"
ARKIME_API_KEY="$4"

echo "Updating AI add-on secrets..."
kubectl create secret generic ai-addon-secrets \
  --namespace ai \
  --from-literal=stamusml-api-url="$STAMUSML_API_URL" \
  --from-literal=stamusml-api-key="$STAMUSML_API_KEY" \
  --from-literal=arkime-api-url="$ARKIME_API_URL" \
  --from-literal=arkime-api-key="$ARKIME_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/stamusml-worker -n ai || true
kubectl rollout restart deployment/arkime-ai-worker -n ai || true

echo "Done. Verify with: kubectl get secret ai-addon-secrets -n ai -o yaml"
