{{/*
# workflow Domain Helper
# Generates the full domain name for workflow service
# Usage: {{ include "common.domain.agenticflow" . }}
# Returns: workflow.<base-domain>
*/}}
{{- define "common.domain.agenticflow" }}
{{- include "common.domain" (dict "ctx" . "sub" "agenticflow") -}}
{{- end }}

{{/*
# workflow External Endpoint Helper
# Generates the complete external access endpoint for workflow service
# Usage: {{ include "common.endpoint.agenticflow" . }}
# Returns: Full URL (http://workflow.<domain> or https://workflow.<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.agenticflow" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.agenticflow" .)) -}}
{{- end }}

{{/*
# csgbot Domain Helper
# Generates the full domain name for csgbot service
# Usage: {{ include "common.domain.csgbot" . }}
# Returns: csgbot.<base-domain>
*/}}
{{- define "common.domain.csgbot" }}
{{- include "common.domain" (dict "ctx" . "sub" "csgbot") -}}
{{- end }}

{{/*
# csgbot External Endpoint Helper
# Generates the complete external access endpoint for csgbot service
# Usage: {{ include "common.endpoint.csgbot" . }}
# Returns: Full URL (http://csgbot.<domain> or https://csgbot.<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.csgbot" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.csgbot" .)) -}}
{{- end }}

{{/*
Generate global unique FLOWS_ACCESS_TOKEN for AgenticFlow

Usage:
{{ include "agenticflow.api.token" . }}

Parameters:
- global: Global context (e.g., .)

Returns: Unique API token string that changes on every installation
*/}}
{{- define "agenticflow.api.token" -}}
  {{- $global := . -}}

  {{- /* Generate random seed for uniqueness across installations */ -}}
  {{- $seed := now | date "200601021504" -}}

  {{- /* Create unique hashes combining release info with random seed */ -}}
  {{- $namespaceHash := (printf "%s-%s" $global.Release.Namespace $seed | sha1sum) -}}
  {{- $nameHash := (printf "%s-%s" $global.Release.Name $seed | sha1sum) -}}

  {{- /* Combine hashes to form final token */ -}}
  {{- printf "%s%s" $namespaceHash $nameHash | sha256sum | trunc 32 | b64enc -}}
{{- end -}}

{{/*# Endpoint Helper
# Resolves the aigateway URL based on configuration:
# 1. If .Values.aigateway.endpoint is set → use it directly
# 2. If isBuiltIn (bundled with csghub) → use csghub's common.endpoint.aigateway
# 3. Otherwise → use <csghub-endpoint>/aigateway
# Usage: {{ include "endpoint.aigateway" . }}
*/}}
{{- define "endpoint.aigateway" }}
{{- $aigateway := .Values.aigateway | default dict }}
{{- if $aigateway.endpoint }}
{{- $aigateway.endpoint -}}
{{- else if .Values.global.chartContext.isBuiltIn }}
{{- include "common.endpoint.aigateway" . -}}
{{- else }}
{{- printf "%s/aigateway" (include "common.endpoint.csghub" .) -}}
{{- end }}
{{- end }}

{{/*
Generate global unique HUB_SERVER_API_TOKEN

Usage:
{{ include "csghub.api.token" . }}

Parameters:
- ctx: Global context (e.g., .)

Returns: Unique API token string that changes on every installation
*/}}
{{- define "csghub.api.token" }}
  {{- $ctx := . }}

  {{- /* Generate random seed for uniqueness across installations */}}
  {{- $seed := now | date "200601021504" }}

  {{- /* Create unique hashes combining release info with random seed */}}
  {{- $namespaceHash := (printf "%s-%s" $ctx.Release.Namespace $seed | sha256sum) }}
  {{- $nameHash := (printf "%s-%s" $ctx.Release.Name $seed | sha256sum) }}

  {{- /* Combine hashes to form final token */}}
  {{- printf "%s%s" $namespaceHash $nameHash }}
{{- end }}
