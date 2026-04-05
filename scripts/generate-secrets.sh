#!/bin/bash
# scripts/generate-secrets.sh
# Run ONCE before first deploy. Generates all secrets and saves credentials.txt
# Never commit credentials.txt to git.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CREDS_FILE="$ROOT_DIR/credentials.txt"

FORCE_ROTATE_SECRETS="${FORCE_ROTATE_SECRETS:-false}"
MISP_BASE_URL="${MISP_BASE_URL:-https://127.0.0.1:18443}"
TRIAGE_API_KEY_OVERRIDE="${TRIAGE_API_KEY:-}"

extract_cred() {
  local key="$1"
  local file="$2"
  grep -F "$key" "$file" 2>/dev/null | sed -E 's/^[^:]+:[[:space:]]*//' | head -n 1
}

echo "=== Generating RADIANT secrets ==="

SHOULD_WRITE_CREDS="true"

# Reuse credentials on rerun unless explicit rotation is requested.
if [ -f "$CREDS_FILE" ] && [ "$FORCE_ROTATE_SECRETS" != "true" ]; then
  echo "Reusing existing credentials from credentials.txt (set FORCE_ROTATE_SECRETS=true to rotate)."
  MYSQL_ROOT="$(extract_cred 'MySQL root password' "$CREDS_FILE")"
  MYSQL_MISP="$(extract_cred 'MySQL MISP password' "$CREDS_FILE")"
  MISP_ADMIN_PASS="$(extract_cred 'MISP admin password' "$CREDS_FILE")"
  MISP_AUTH_KEY="$(extract_cred 'MISP auth key' "$CREDS_FILE")"
  SHUFFLE_DB_PASS="$(extract_cred 'Shuffle DB password' "$CREDS_FILE")"
  TRIAGE_API_KEY_VALUE="$(extract_cred 'Triage API key' "$CREDS_FILE")"

  # Keep credentials.txt unchanged on reruns unless we must regenerate values.
  SHOULD_WRITE_CREDS="false"
else
  # Generate passwords
  MYSQL_ROOT=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)
  MYSQL_MISP=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)
  MISP_ADMIN_PASS=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)
  MISP_AUTH_KEY=$(openssl rand -hex 32)
  SHUFFLE_DB_PASS=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)
  TRIAGE_API_KEY_VALUE="REPLACE_WITH_YOUR_TRIAGE_KEY"
fi

# Allow explicit API key override from environment for non-interactive runs.
if [ -n "$TRIAGE_API_KEY_OVERRIDE" ]; then
  TRIAGE_API_KEY_VALUE="$TRIAGE_API_KEY_OVERRIDE"
  SHOULD_WRITE_CREDS="true"
fi

# Fill missing values defensively.
[ -n "$MYSQL_ROOT" ] || { MYSQL_ROOT=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20); SHOULD_WRITE_CREDS="true"; }
[ -n "$MYSQL_MISP" ] || { MYSQL_MISP=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20); SHOULD_WRITE_CREDS="true"; }
[ -n "$MISP_ADMIN_PASS" ] || { MISP_ADMIN_PASS=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20); SHOULD_WRITE_CREDS="true"; }
[ -n "$MISP_AUTH_KEY" ] || { MISP_AUTH_KEY=$(openssl rand -hex 32); SHOULD_WRITE_CREDS="true"; }
[ -n "$SHUFFLE_DB_PASS" ] || { SHUFFLE_DB_PASS=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20); SHOULD_WRITE_CREDS="true"; }
[ -n "$TRIAGE_API_KEY_VALUE" ] || { TRIAGE_API_KEY_VALUE="REPLACE_WITH_YOUR_TRIAGE_KEY"; SHOULD_WRITE_CREDS="true"; }

# Save credentials locally (gitignored) only when values changed/rotated.
if [ "$SHOULD_WRITE_CREDS" = "true" ]; then
cat > "$CREDS_FILE" << EOF
# RADIANT Project Credentials
# Generated: $(date)
# DO NOT COMMIT THIS FILE

MySQL root password:     $MYSQL_ROOT
MySQL MISP password:     $MYSQL_MISP
MISP admin password:     $MISP_ADMIN_PASS
MISP auth key:           $MISP_AUTH_KEY
Shuffle DB password:     $SHUFFLE_DB_PASS

# Add your Hatching Triage API key below after registering at https://tria.ge
Triage API key:          $TRIAGE_API_KEY_VALUE
EOF

chmod 600 "$CREDS_FILE"
echo "Credentials saved to credentials.txt"
else
echo "Credentials unchanged (idempotent rerun)."
fi

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
  --from-literal=base-url="$MISP_BASE_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

# AI namespace - Triage API key placeholder
kubectl create secret generic triage-secret \
  --namespace ai \
  --from-literal=api-key="$TRIAGE_API_KEY_VALUE" \
  --from-literal=misp-url="http://misp.ati.svc.cluster.local" \
  --from-literal=misp-key="$MISP_AUTH_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# AI namespace - StamusML / Arkime AI placeholders
kubectl create secret generic ai-addon-secrets \
  --namespace ai \
  --from-literal=stamusml-api-url="" \
  --from-literal=stamusml-api-key="" \
  --from-literal=arkime-api-url="" \
  --from-literal=arkime-api-key="" \
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
if [ "$FORCE_ROTATE_SECRETS" = "true" ]; then
  echo "Rotation mode: FORCE_ROTATE_SECRETS=true (all generated credentials rotated)."
else
  echo "Idempotent mode: existing credentials reused when present."
fi
echo "IMPORTANT: Open credentials.txt and add your Triage API key, then run:"
echo "  kubectl create secret generic triage-secret --namespace ai \\"
echo "    --from-literal=api-key=YOUR_KEY --dry-run=client -o yaml | kubectl apply -f -"
echo "Optional: set StamusML/Arkime API endpoints and keys with:"
echo "  bash scripts/update-ai-addon-secrets.sh STAMUSML_API_URL STAMUSML_API_KEY ARKIME_API_URL ARKIME_API_KEY"
echo ""
echo "Verify secrets:"
echo "  kubectl get secrets -A"
