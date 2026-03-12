#!/bin/bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-csghub}"
RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-csghub}"
SPACE_NAMESPACE="${SPACE_NAMESPACE:-spaces}"

if ! command -v kubectl &>/dev/null; then
  echo "Error: kubectl not found"
  exit 1
fi

patch_resource() {
  local resource_name=$1
  local namespace=${2:-}

  if [ -n "$namespace" ]; then
    kubectl label "$resource_name" -n "$namespace" app.kubernetes.io/managed-by=Helm --overwrite
    kubectl annotate "$resource_name" -n "$namespace" \
      meta.helm.sh/release-name="$RELEASE_NAME" \
      meta.helm.sh/release-namespace="$RELEASE_NAMESPACE" --overwrite
  else
    kubectl label "$resource_name" app.kubernetes.io/managed-by=Helm --overwrite
    kubectl annotate "$resource_name" \
      meta.helm.sh/release-name="$RELEASE_NAME" \
      meta.helm.sh/release-namespace="$RELEASE_NAMESPACE" --overwrite
  fi
}

process_resource_list() {
  local list="$1"
  local action="$2"

  while read -r item; do
    if [ -n "$item" ]; then
      MANAGED=$(kubectl get "$item" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null)

      if [ "$MANAGED" != "Helm" ]; then
        if [ "$action" = "patch_crd" ]; then
          patch_resource "$item"
          echo "Patched CRD: $item"
        elif [ "$action" = "delete" ]; then
          kubectl delete "$item"
          echo "Deleted: $item"
        fi
      fi
    fi
  done <<< "$list"
}

# ---- CRD Patch ----
echo "Patching CRDs..."
CRD_LIST=$(kubectl get crd -o name | grep -E 'argoproj.io|knative.dev|leaderworkerset' || true)
if [ -z "$CRD_LIST" ]; then
  echo "No matching CRDs found"
else
  process_resource_list "$CRD_LIST" "patch_crd"
fi
echo "Patching CRDs Done."

# ---- MutatingWebhookConfiguration Patch ----
echo
echo "Deleting LWS MutatingWebhookConfiguration..."
MWC_LIST=$(kubectl get MutatingWebhookConfiguration -o name | grep 'lws' || true)
if [ -z "$MWC_LIST" ]; then
  echo "No matching MutatingWebhookConfiguration found"
else
  process_resource_list "$MWC_LIST" "delete"
fi
echo "Deleting LWS MutatingWebhookConfiguration Done."

# ---- ValidatingWebhookConfiguration Patch ----
echo
echo "Deleting LWS ValidatingWebhookConfiguration..."
VWC_LIST=$(kubectl get ValidatingWebhookConfiguration -o name | grep 'lws' || true)
if [ -z "$VWC_LIST" ]; then
  echo "No matching ValidatingWebhookConfiguration found"
else
  process_resource_list "$VWC_LIST" "delete"
fi
echo "Deleting LWS ValidatingWebhookConfiguration Done."