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
