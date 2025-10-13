{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# Prometheus Domain Helper
# Generates the full domain name for Prometheus service based on configuration
# Usage: {{ include "common.domain.prometheus" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.prometheus" -}}
{{- $service := include "common.service" (dict "service" "prometheus" "global" .) | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# Prometheus External Endpoint Helper
# Generates the complete external access endpoint for Prometheus service
# Usage: {{ include "common.endpoint.prometheus" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.prometheus" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.prometheus" .)) -}}
{{- end }}
