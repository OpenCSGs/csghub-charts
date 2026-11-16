#!/usr/bin/env bash
# Create Substrate identity Secrets once per cluster. Helm does not generate
# CA / JWT pool formats; use kubectl-ate from the same release as the chart
# appVersion (v1.0.0).
set -euo pipefail

NAMESPACE="${1:-ate-system}"
CONTEXT="${KUBE_CONTEXT:-}"

ate=(kubectl-ate)
kc=(kubectl)
if [[ -n "$CONTEXT" ]]; then
  ate+=( --context "$CONTEXT" )
  kc+=( --context "$CONTEXT" )
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need_cmd kubectl-ate
need_cmd kubectl

ensure_ca_pool() {
  local ns="$1" name="$2" key_type="$3"
  if "${kc[@]}" -n "$ns" get secret "$name" >/dev/null 2>&1; then
    echo "keep ${ns}/${name}"
    return
  fi
  echo "create ${ns}/${name} (${key_type})"
  "${ate[@]}" admin make-ca-pool \
    --secret-namespace "$ns" \
    --name "$name" \
    --key-type "$key_type" \
    --ca-id 1
}

ensure_jwt_pool() {
  local ns="$1" name="$2"
  if "${kc[@]}" -n "$ns" get secret "$name" >/dev/null 2>&1; then
    echo "keep ${ns}/${name}"
    return
  fi
  echo "create ${ns}/${name}"
  "${ate[@]}" admin make-jwt-pool \
    --secret-namespace "$ns" \
    --name "$name" \
    --alg ES256
}

echo "Bootstrapping identity in namespace ${NAMESPACE}"
"${kc[@]}" get ns "$NAMESPACE" >/dev/null 2>&1 || "${kc[@]}" create namespace "$NAMESPACE"

ensure_ca_pool "$NAMESPACE" actor-id-ca-pool ECDSAP256
ensure_jwt_pool "$NAMESPACE" actor-id-jwt-pool
ensure_ca_pool "$NAMESPACE" egress-mitm-ca-pool ECDSAP256

# Certs-only trust bundle for components that must not mount the signing key.
if ! "${kc[@]}" -n "$NAMESPACE" get secret actor-id-ca-certs >/dev/null 2>&1; then
  echo "create ${NAMESPACE}/actor-id-ca-certs"
  "${kc[@]}" -n "$NAMESPACE" get secret actor-id-ca-pool -o jsonpath='{.data.tls\.crt}' | base64 -d >/tmp/actor-id-ca.crt
  "${kc[@]}" -n "$NAMESPACE" create secret generic actor-id-ca-certs --from-file=ca.crt=/tmp/actor-id-ca.crt
  rm -f /tmp/actor-id-ca.crt
else
  echo "keep ${NAMESPACE}/actor-id-ca-certs"
fi

PCNS=podcertificate-controller-system
"${kc[@]}" get ns "$PCNS" >/dev/null 2>&1 || "${kc[@]}" create namespace "$PCNS"
ensure_ca_pool "$PCNS" service-dns-ca-pool ED25519
ensure_ca_pool "$PCNS" pod-identity-ca-pool ED25519
ensure_ca_pool "$PCNS" postgres-ca-pool ED25519

echo "Identity bootstrap finished for ${NAMESPACE} (and ${PCNS})."
echo "Re-run is safe: existing pools are kept."
