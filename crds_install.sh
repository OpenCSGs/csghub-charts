#!/bin/bash
set -euo pipefail

# -----------------------------
# 配置区
# -----------------------------
BASE_REPO_URL="${GHPROXY:-https://ghfast.top/}https://raw.githubusercontent.com/OpenCSGs/csghub-charts/refs/heads/main/charts/csghub/charts/gateway-helm/crds/"
CRD_FILES=(
  "gatewayapi-crds.yaml"
  "generated/gateway.envoyproxy.io_backends.yaml"
  "generated/gateway.envoyproxy.io_backendtrafficpolicies.yaml"
  "generated/gateway.envoyproxy.io_clienttrafficpolicies.yaml"
  "generated/gateway.envoyproxy.io_envoyextensionpolicies.yaml"
  "generated/gateway.envoyproxy.io_envoypatchpolicies.yaml"
  "generated/gateway.envoyproxy.io_envoyproxies.yaml"
  "generated/gateway.envoyproxy.io_httproutefilters.yaml"
  "generated/gateway.envoyproxy.io_securitypolicies.yaml"
)

# -----------------------------
# 函数区
# -----------------------------
apply_crd() {
  local file="$1"
  local url="${BASE_REPO_URL}${file}"
  echo "⬇️  Applying CRD: ${file}"



  if kubectl apply --server-side -f "${url}" &>/dev/null; then
    echo "✅ Successfully created ${file}"
    echo
  else
    echo "❌ Failed to create ${file}"
    exit 1
  fi
}

# -----------------------------
# 主流程
# -----------------------------
echo "🌐 Starting to created CRDs via server-side apply..."
echo

for crd_file in "${CRD_FILES[@]}"; do
  apply_crd "${crd_file}"
done

echo "🎉 All CRDs created successfully."