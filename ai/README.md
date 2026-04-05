# RADIANT AI Add-ons (Kubernetes Modular Template)

This folder is a modular Kubernetes deployment layer for AI add-ons in Project RADIANT.

## Structure

- [ai/enrichment/enrichment.yaml](ai/enrichment/enrichment.yaml): Hatching Triage enrichment + MISP write-back
- [ai/stamusml/stamusml.yaml](ai/stamusml/stamusml.yaml): StamusML-style anomaly scoring worker
- [ai/arkime-ai/arkime-ai.yaml](ai/arkime-ai/arkime-ai.yaml): Arkime AI-style traffic tagging worker
- [ai/kustomization.yaml](ai/kustomization.yaml): Single entrypoint to deploy all AI modules

## Deploy AI modules

```bash
kubectl apply -k ai
```

## Configure API secrets (optional integrations)

```bash
bash scripts/update-ai-addon-secrets.sh \
  STAMUSML_API_URL STAMUSML_API_KEY \
  ARKIME_API_URL ARKIME_API_KEY
```

## Extend template for final project

1. Copy an existing module folder (`stamusml` or `arkime-ai`) as a baseline.
2. Rename resource names and labels.
3. Add your model/API logic in the ConfigMap script or a custom container image.
4. Add the new manifest path to [ai/kustomization.yaml](ai/kustomization.yaml).
5. Redeploy with `kubectl apply -k ai`.
