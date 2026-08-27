#!/bin/bash
set -euo pipefail
trap 'rm -rf "${TMP_DIR:-}"' EXIT

# -----------------------------
CHART_VERSION="${CHART_VERSION:-latest}"
CHART_BASE_URL="${CHART_BASE_URL:-https://charts.opencsg.com/csghub}"
# Comma-separated services whose CRDs should be installed.
# Supported values: gateway-helm, agent-sandbox. Default: all
CRD_SERVICES="${CRD_SERVICES:-all}"
TMP_DIR=$(mktemp -d)
EXTRACT_DIR="${TMP_DIR}/extract"

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

  CHART_VERSION=$(sed -n '/^  csghub:/,/^  [a-z]/p' "${INDEX_FILE}" \
    | grep "^    version:" \
    | awk '{print $2}' \
    | grep -v '-' \
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

echo "🔍 Locating CRD directories..."

GATEWAY_CRD_DIR=$(find "${EXTRACT_DIR}" -type d -path "*/gateway-helm/crds" | head -n1)
AGENT_SANDBOX_CRD_DIR=$(find "${EXTRACT_DIR}" -type d -path "*/runner/charts/agent-sandbox/crds" | head -n1)

# Returns 0 if the given service's CRDs should be installed.
should_install() {
  [[ "${CRD_SERVICES}" == "all" || ",${CRD_SERVICES}," == *",$1,"* ]]
}

apply_crds() {
  local crd_dir="$1"
  local label="$2"

  if [[ -z "${crd_dir}" ]]; then
    echo "❌ ${label} CRD directory not found after extraction"
    exit 1
  fi

  echo "📂 Using ${label} CRDs from: ${crd_dir}"

  local crd_count
  crd_count=$(find "${crd_dir}" -type f \( -name "*.yaml" -o -name "*.yml" \) | wc -l)

  if [[ "${crd_count}" -eq 0 ]]; then
    echo "❌ No CRD files found in ${crd_dir}"
    exit 1
  fi

  echo "📊 Found ${crd_count} CRD files"

  echo "🚀 Applying ${label} CRDs via server-side apply..."

  if ! kubectl apply --server-side --recursive --force-conflicts -f "${crd_dir}"; then
    echo
    echo "❌ Failed to apply ${label} CRDs"
    exit 1
  fi
  echo
  echo "🎉 ${label} CRDs created successfully."
}

echo "🚀 Applying CRDs via server-side apply..."

for entry in "gateway-helm:${GATEWAY_CRD_DIR}" "agent-sandbox:${AGENT_SANDBOX_CRD_DIR}"; do
  service="${entry%%:*}"
  crd_dir="${entry#*:}"

  if ! should_install "${service}"; then
    echo "⏭️  Skipping ${service} CRDs (not in CRD_SERVICES=${CRD_SERVICES})"
    continue
  fi

  apply_crds "${crd_dir}" "${service}"
done