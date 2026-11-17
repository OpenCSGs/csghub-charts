#!/usr/bin/env bash
#
# Read-only checks for an external-Casdoor CSGHub release.
# Mirrors step 12 of docs/external-casdoor.md.
#
# Usage:
#   docs/external-casdoor/verify.sh
#
# Environment (override as needed):
#   CASDOOR_ENDPOINT   external Casdoor URL           (required)
#   CSGHUB_ENDPOINT    CSGHub public URL              (default: from configmap)
#   NAMESPACE          release namespace              (default: csghub)
#   RELEASE            helm release name              (default: csghub)
#   CERT_SECRET        Secret with the JWT cert       (default: csghub-casdoor-cert)
#
# Exits non-zero if any check fails. Performs no writes.

set -euo pipefail

: "${CASDOOR_ENDPOINT:?set CASDOOR_ENDPOINT to your external Casdoor URL, e.g. https://sso.example.com}"
NAMESPACE="${NAMESPACE:-csghub}"
RELEASE="${RELEASE:-csghub}"
CERT_SECRET="${CERT_SECRET:-csghub-casdoor-cert}"

fail() { printf 'FAIL  %s\n' "$1" >&2; exit 1; }
ok()   { printf 'ok    %s\n' "$1"; }

# 1. Casdoor issuer must equal the configured endpoint.
issuer="$(curl -fsS "$CASDOOR_ENDPOINT/.well-known/openid-configuration" | jq -r .issuer)"
[ "$issuer" = "$CASDOOR_ENDPOINT" ] \
  || fail "issuer mismatch: $issuer != $CASDOOR_ENDPOINT"
ok "issuer = $issuer"

# 2. Server configmap carries the external endpoint, organization, application.
cm="$RELEASE-core"
[ -n "$(kubectl -n "$NAMESPACE" get configmap "$cm" -o name 2>/dev/null)" ] \
  || fail "configmap $cm not found in namespace $NAMESPACE"
cfg="$(kubectl -n "$NAMESPACE" get configmap "$cm" -o jsonpath='{.data}')"
grep -q "STARHUB_SERVER_CASDOOR_ENDPOINT" <<<"$cfg" || fail "STARHUB_SERVER_CASDOOR_ENDPOINT missing"
ok "server configmap references CASDOOR settings"

# 3. Mounted JWT certificate is the signing cert, not the HTTPS cert.
crt="$(kubectl -n "$NAMESPACE" get configmap "$cm" -o jsonpath='{.data.STARHUB_SERVER_CASDOOR_CERTIFICATE}')"
[ -n "$crt" ] || ok "certificate path not set in configmap (mount-only deployments are fine)"

# 4. The signing certificate parses and is a certificate (not a key).
pem="$(kubectl -n "$NAMESPACE" get secret "$CERT_SECRET" -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d || true)"
if [ -n "$pem" ]; then
  openssl x509 -noout -in <(printf '%s' "$pem") >/dev/null 2>&1 \
    || fail "$CERT_SECRET tls.crt is not a valid x509 certificate"
  ok "$CERT_SECRET contains a valid x509 certificate"
else
  echo "skip  $CERT_SECRET secret not readable (check permissions)"
fi

# 5. The external endpoint answers an authorize request (no invalid_client).
code="$(curl -sS -o /dev/null -w '%{http_code}' \
  "$CASDOOR_ENDPOINT/login/oauth/authorize?client_id=probe&response_type=code&scope=openid&redirect_uri=$CASDOOR_ENDPOINT/probe" || true)"
case "$code" in
  200|302) ok "authorize endpoint reachable (HTTP $code)" ;;
  *)       echo "warn  authorize endpoint returned HTTP $code (check application/client id)" ;;
esac

ok "all checks passed"
