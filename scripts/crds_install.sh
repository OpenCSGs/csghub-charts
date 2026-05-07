#!/bin/bash
set -euo pipefail
trap 'rm -rf "${TMP_DIR:-}"' EXIT

# -----------------------------
# 配置区
# -----------------------------
CHART_VERSION="${CHART_VERSION:-latest}"
CHART_BASE_URL="${CHART_BASE_URL:-https://charts.opencsg.com/csghub}"
TMP_DIR=$(mktemp -d)
EXTRACT_DIR="${TMP_DIR}/extract"
CRD_DIR="${EXTRACT_DIR}/csghub/charts/gateway-helm/crds"

# -----------------------------
# 函数区
# -----------------------------

# -----------------------------
# 主流程
# -----------------------------
mkdir -p "${EXTRACT_DIR}"

command -v curl >/dev/null 2>&1 || {
  echo "❌ curl is required"
  exit 1
}

command -v tar >/dev/null 2>&1 || {
  echo "❌ tar is required"
  exit 1
}

command -v kubectl >/dev/null 2>&1 || {
  echo "❌ kubectl is required"
  exit 1
}

echo "🌐 Downloading csghub chart package..."

if [[ "${CHART_VERSION}" == "latest" ]]; then
  echo "🌐 Resolving latest chart version from index.yaml..."

  INDEX_FILE="${TMP_DIR}/index.yaml"

  curl -fsSL "${CHART_BASE_URL}/index.yaml" -o "${INDEX_FILE}"

  CHART_VERSION=$(awk '/version:/ {print $2}' "${INDEX_FILE}" \
    | sort -Vr \
    | head -n1)

  if [[ -z "${CHART_VERSION}" ]]; then
    echo "❌ Failed to resolve latest chart version"
    exit 1
  fi
fi

CHART_URL="${CHART_BASE_URL}/csghub-${CHART_VERSION}.tgz"
CHART_FILE="${TMP_DIR}/csghub-${CHART_VERSION}.tgz"

echo "⬇️ ${CHART_URL}"

if ! curl -sSfL --retry 3 --connect-timeout 10 "${CHART_URL}" -o "${CHART_FILE}"; then
  echo "❌ Failed to download chart package"
  exit 1
fi

echo "📦 Extracting chart package..."
if ! tar -xzf "${CHART_FILE}" -C "${EXTRACT_DIR}"; then
  echo "❌ Failed to extract chart package"
  exit 1
fi

echo "📂 Using CRDs from: ${CRD_DIR}"

if [[ ! -d "${CRD_DIR}" ]]; then
  echo "❌ CRD directory not found: ${CRD_DIR}"
  exit 1
fi

echo "🚀 Applying CRDs via server-side apply..."

if kubectl apply --server-side -f "${CRD_DIR}"; then
  echo
  echo "🎉 All CRDs created successfully."
else
  echo
  echo "❌ Failed to apply CRDs"
  exit 1
fi