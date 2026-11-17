{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
# Casdoor JWT certificate volume

The CSGHub server, user and executor deployments validate Casdoor-issued JWTs
against tls.crt. Bundled Casdoor keeps the certificate in the <casdoor>-init
Secret; external Casdoor uses global.casdoor.external.existingSecret.

Usage:
  volumes:
    {{- include "csghub.casdoor.certVolume" . | nindent 8 }}
*/}}
{{- define "csghub.casdoor.certVolume" -}}
{{- $global := .Values.global | default dict }}
{{- $external := dig "casdoor" "external" (dict) $global }}
- name: casdoor-init-certs
  secret:
    {{- if dig "casdoor" "enabled" true $global }}
    {{- $casdoorSvc := include "common.service" (dict "ctx" . "service" "casdoor") | fromYaml }}
    secretName: {{ include "common.names.custom" (list . (printf "%s-init" $casdoorSvc.name)) }}
    items:
      - key: tls.crt
        path: tls.crt
      - key: tls.key
        path: tls.key
    {{- else }}
    secretName: {{ required "global.casdoor.external.existingSecret is required when global.casdoor.enabled=false" $external.existingSecret }}
    items:
      - key: tls.crt
        path: tls.crt
    {{- end }}
{{- end }}
