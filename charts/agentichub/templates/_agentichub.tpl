{{/*
# csghub Domain Helper
# Generates the full domain name for csghub service based on configuration
# Usage: {{ include "common.domain.csghub" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.csghub" }}
{{- $domain := "" }}
{{- if hasKey .Values.global.gateway "external" }}
  {{- if hasKey .Values.global.gateway.external "domain" }}
    {{- $domain = .Values.global.gateway.external.domain }}
  {{- end }}
{{- end }}
{{- $domain -}}
{{- end }}

{{/*
# csghub External Endpoint Helper
# Generates the complete external access endpoint for csghub service
# Usage: {{ include "common.endpoint.csghub" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.csghub" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.csghub" .)) -}}
{{- end }}

{{/*
# workflow Domain Helper
# Generates the full domain name for workflow service
# Usage: {{ include "common.domain.workflow" . }}
# Returns: workflow.<base-domain>
*/}}
{{- define "common.domain.workflow" }}
{{- include "common.domain" (dict "ctx" . "sub" "workflow") -}}
{{- end }}

{{/*
# workflow External Endpoint Helper
# Generates the complete external access endpoint for workflow service
# Usage: {{ include "common.endpoint.workflow" . }}
# Returns: Full URL (http://workflow.<domain> or https://workflow.<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.workflow" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.workflow" .)) -}}
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

{{/*
# memmachine Domain Helper
# Generates the full domain name for memmachine service
# Usage: {{ include "common.domain.memmachine" . }}
# Returns: memmachine.<base-domain>
*/}}
{{- define "common.domain.memmachine" }}
{{- include "common.domain" (dict "ctx" . "sub" "memmachine") -}}
{{- end }}

{{/*
# memmachine External Endpoint Helper
# Generates the complete external access endpoint for memmachine service
# Usage: {{ include "common.endpoint.memmachine" . }}
# Returns: Full URL (http://memmachine.<domain> or https://memmachine.<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.memmachine" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.memmachine" .)) -}}
{{- end }}

