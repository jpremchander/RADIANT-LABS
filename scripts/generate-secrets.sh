#!/bin/bash
# scripts/generate-secrets.sh
# Run ONCE before first deploy. Generates all secrets and saves credentials.txt
# Never commit credentials.txt to git.

set -e

echo "=== Generating RADIANT secrets ==="

# Generate passwords
MYSQL_ROOT=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)
MYSQL_MISP=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)
MISP_ADMIN_PASS=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)
MISP_AUTH_KEY=$(openssl rand -hex 32)
SHUFFLE_DB_PASS=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)

# Save credentials locally (gitignored)
cat > "$(dirname "$0")/../credentials.txt" << EOF
# RADIANT Project Credentials
# Generated: $(date)
# DO NOT COMMIT THIS FILE

MySQL root password:     $MYSQL_ROOT
MySQL MISP password:     $MYSQL_MISP
MISP admin password:     $MISP_ADMIN_PASS
MISP auth key:           $MISP_AUTH_KEY
Shuffle DB password:     $SHUFFLE_DB_PASS

# Add your Hatching Triage API key below after registering at https://tria.ge
Triage API key:          REPLACE_WITH_YOUR_TRIAGE_KEY
EOF

chmod 600 "$(dirname "$0")/../credentials.txt"
echo "Credentials saved to credentials.txt"

# Create Kubernetes secrets
echo "Creating Kubernetes secrets..."

# ATI namespace - MySQL
kubectl create secret generic mysql-secret \
  --namespace ati \
  --from-literal=root-password="$MYSQL_ROOT" \
  --from-literal=misp-password="$MYSQL_MISP" \
  --from-literal=misp-database=misp \
  --dry-run=client -o yaml | kubectl apply -f -

# ATI namespace - MISP
kubectl create secret generic misp-secret \
  --namespace ati \
  --from-literal=admin-password="$MISP_ADMIN_PASS" \
  --from-literal=auth-key="$MISP_AUTH_KEY" \
  --from-literal=base-url="http://misp.lab" \
  --dry-run=client -o yaml | kubectl apply -f -

# AI namespace - Triage API key placeholder
kubectl create secret generic triage-secret \
  --namespace ai \
  --from-literal=api-key="REPLACE_WITH_YOUR_TRIAGE_KEY" \
  --from-literal=misp-url="http://misp.ati.svc.cluster.local" \
  --from-literal=misp-key="$MISP_AUTH_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# SOAR namespace - Shuffle
kubectl create secret generic shuffle-secret \
  --namespace soar \
  --from-literal=db-password="$SHUFFLE_DB_PASS" \
  --from-literal=misp-url="http://misp.ati.svc.cluster.local" \
  --from-literal=misp-key="$MISP_AUTH_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== Secrets created successfully ==="
echo ""
echo "IMPORTANT: Open credentials.txt and add your Triage API key, then run:"
echo "  kubectl create secret generic triage-secret --namespace ai \\"
echo "    --from-literal=api-key=YOUR_KEY --dry-run=client -o yaml | kubectl apply -f -"
echo ""
echo "Verify secrets:"
echo "  kubectl get secrets -A"
