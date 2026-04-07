#!/usr/bin/env bash

set -euo pipefail

# 1. Handle sed compatibility (macOS requires gnu-sed)
SED_BIN="sed"
if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v gsed &>/dev/null; then
        SED_BIN="gsed"
    else
        echo "Error: macOS detected, please install gnu-sed: brew install gnu-sed"
        exit 1
    fi
fi

# 2. Setup PATH for Krew and plugins
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

if ! kubectl krew version &>/dev/null; then
    echo "Krew not found, installing..."
    (
        set -x
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        OS="$(uname | tr '[:upper:]' '[:lower:]')"
        ARCH="$(uname -m | $SED_BIN -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64/arm64/')"
        KREW="krew-${OS}_${ARCH}"
        curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
        tar zxvf "${KREW}.tar.gz"
        ./"${KREW}" install krew
    )
fi

if ! kubectl slice --help &>/dev/null; then
    echo "Installing kubectl-slice plugin..."
    kubectl krew install slice
fi

# 3. Configuration & Directory Setup
VERSION="v0.2.1"
BASE_URL="https://ghfast.top/https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}"
TEMPLATE_DIR="templates"
EXT_DIR="${TEMPLATE_DIR}/extensions"
CRD_DIR="crds"
VALUES_FILE="values.yaml"

# Clean start
rm -rf "$TEMPLATE_DIR" "$CRD_DIR" "$VALUES_FILE"
mkdir -p "$EXT_DIR" "$CRD_DIR"

# 4. Fetch and Split manifests
echo "Fetching and splitting manifests..."
curl -sfl "${BASE_URL}/manifest.yaml" | kubectl slice \
    --template "{{.kind | lower}}-{{.metadata.name}}.yaml" \
    -o "$TEMPLATE_DIR"

curl -sfl "${BASE_URL}/extensions.yaml" | kubectl slice \
    --template "{{.kind | lower}}-{{.metadata.name}}.yaml" \
    -o "$EXT_DIR"

# 5. Extract Image Metadata for values.yaml
SAMPLE_FILE=$(find "$TEMPLATE_DIR" -name "deployment-agent-sandbox-controller.yaml" | head -n 1)

if [[ -f "$SAMPLE_FILE" ]]; then
    echo "Extracting image metadata..."
    FULL_IMAGE=$(grep "image:" "$SAMPLE_FILE" | head -n 1 | awk '{print $2}')
    REGISTRY=$(echo "$FULL_IMAGE" | cut -d'/' -f1)
    REPO_TAG=$(echo "$FULL_IMAGE" | cut -d'/' -f2-)
    REPOSITORY=$(echo "$REPO_TAG" | cut -d':' -f1)
    TAG=$(echo "$REPO_TAG" | cut -d':' -f2)

    cat <<EOF > "$VALUES_FILE"
global:
  image:
    registry: "$REGISTRY"

image:
  # registry: "$REGISTRY"
  repository: $REPOSITORY
  tag: $TAG
EOF
    echo "Created $VALUES_FILE"
fi

# 6. Cleanup and Organization
echo "Removing Namespace resources..."
find "$TEMPLATE_DIR" -maxdepth 1 -type f \( -name "namespace-*.yaml" -o -name "deployment-*.yaml" \) -delete

echo "Moving CRDs to /crds..."
find "$TEMPLATE_DIR" -name "customresourcedefinition-*.yaml" -exec mv {} "$CRD_DIR/" \;

# 7. Helm Transformations
echo "Applying Helm template logic..."

# A. Replace Image references
find "$TEMPLATE_DIR" -type f -name "*.yaml" -exec "$SED_BIN" -i \
    's|image: .*|image: {{ include "common.image" (list . .Values.image) \| replace "docker.io" "registry.k8s.io" }}|g' {} +

# B. Replace hardcoded Namespace
find "$TEMPLATE_DIR" -type f -name "*.yaml" -exec "$SED_BIN" -i \
    's/namespace: agent-sandbox-system/namespace: {{ .Release.Namespace }}/g' {} +

# C. Append labels to metadata.labels (Indentation: 4 spaces for the helper)
# Use [[:space:]]* to handle any number of spaces before 'labels:'
echo "Appending labels to metadata..."
find "$TEMPLATE_DIR" -type f -name "*.yaml" -exec "$SED_BIN" -i \
    '/^metadata:/,/^spec:/ {
        s/^[[:space:]]\{2\}labels:/  labels:\n    {{- include "common.labels" . | nindent 4 }}/
    }' {} +

# D. Append labels to spec.template.metadata.labels (Indentation: 8 spaces for the helper)
# Look for 'labels:' that is nested deeper (usually 6 spaces) within the template block
echo "Appending labels to pod templates..."
find "$TEMPLATE_DIR" -type f -name "*.yaml" -exec "$SED_BIN" -i \
    '/^  template:/,/^    spec:/ {
        s/^[[:space:]]\{6\}labels:/      labels:\n        {{- include "common.labels" . | nindent 8 }}/
    }' {} +

# E. Final cleanup: Remove any trailing whitespace created by the script
find "$TEMPLATE_DIR" -type f -name "*.yaml" -exec "$SED_BIN" -i 's/[[:space:]]*$//' {} +

echo "Success: Managed manifests in ./templates and ./crds"