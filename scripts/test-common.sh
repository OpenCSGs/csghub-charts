#!/usr/bin/env bash
# Run helm-unittest for the common library chart.
#
# helm-unittest cannot render library charts (type: library) because Helm does
# not render any templates for them. This script temporarily switches
# Chart.yaml to type: application, runs the tests, then restores it. The tests
# render the define-based fixtures in templates/fixtures/, which stub the
# csghub-only endpoint templates (common.endpoint.minio / common.endpoint.csghub).
set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../charts/common" && pwd)"
cd "$CHART_DIR"

if [ ! -d tests ]; then
  echo "No tests directory in common chart, skipping."
  exit 0
fi

if ! helm plugin list | grep -q unittest; then
  echo "❌ Helm unittest plugin not installed. Install with:"
  echo "   helm plugin install https://github.com/helm-unittest/helm-unittest"
  exit 1
fi

restore_type() {
  if [ -n "${ORIGINAL_TYPE:-}" ]; then
    sed "s/^type: application$/type: ${ORIGINAL_TYPE}/" Chart.yaml > Chart.yaml.tmp
    mv Chart.yaml.tmp Chart.yaml
  fi
}
trap restore_type EXIT

ORIGINAL_TYPE="$(sed -n 's/^type: *\(.*\)$/\1/p' Chart.yaml)"
if [ "$ORIGINAL_TYPE" = "library" ]; then
  sed 's/^type: library$/type: application/' Chart.yaml > Chart.yaml.tmp
  mv Chart.yaml.tmp Chart.yaml
fi

helm unittest .
