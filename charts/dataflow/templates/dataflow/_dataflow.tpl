{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# Dataflow Domain Helper
# Generates the full domain name for Dataflow service based on configuration
# Usage: {{ include "common.domain.dataflow" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.dataflow" -}}
{{- $service := include "common.service" (dict "ctx" . "service" "dataflow") | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# Dataflow External Endpoint Helper
# Generates the complete external access endpoint for Dataflow service
# Usage: {{ include "common.endpoint.dataflow" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.dataflow" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.dataflow" .)) -}}
{{- end }}