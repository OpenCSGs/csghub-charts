{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# Loki Domain Helper
# Generates the full domain name for Loki service based on configuration
# Usage: {{ include "common.domain.loki" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.loki" -}}
{{- $service := include "common.service" (dict "service" "loki" "global" .) | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# Loki External Endpoint Helper
# Generates the complete external access endpoint for Loki service
# Usage: {{ include "external.endpoint.loki" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.loki" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.loki" .)) -}}
{{- end }}
