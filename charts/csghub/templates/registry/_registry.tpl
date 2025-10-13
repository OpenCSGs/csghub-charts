{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# Registry Domain Helper
# Generates the full domain name for Registry service based on configuration
# Usage: {{ include "common.domain.registry" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.registry" -}}
{{- $service := include "common.service" (dict "service" "registry" "global" .) | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# Registry External Endpoint Helper
# Generates the complete external access endpoint for Registry service
# Usage: {{ include "common.endpoint.registry" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.registry" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.registry" .)) -}}
{{- end }}