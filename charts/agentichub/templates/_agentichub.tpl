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
# 2. If isBuiltIn (bundled with csghub) → use common.endpoint.aigateway
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
