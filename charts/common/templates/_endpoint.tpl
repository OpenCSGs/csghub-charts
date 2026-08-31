{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Construct the external endpoint for csghub with flexible configuration.

Priority:
1. Service-specific gateway configuration
2. Global gateway configuration

Parameters can be passed as a dict with:
- ctx: The Helm context
- service: Service-specific values (optional)
- domain: Domain for the endpoint

Usage:
{{ include "common.endpoint" (dict "ctx" . "service" .Values.webapp "domain" "app.example.com") }}
*/}}
{{- define "common.endpoint" }}
  {{- /* Parse parameters */}}
  {{- $ctx := .ctx }}
  {{- $service := .service | default dict }}
  {{- $domain := .domain }}

  {{- /* Get merged gateway configuration using common.gateway.config */}}
  {{- $gatewayConfig := include "common.gateway.config" (dict "ctx" $ctx "service" $service) | fromYaml }}
  
  {{- /* Determine protocol and port based on configuration */}}
  {{- $scheme := "http" }}
  {{- if $gatewayConfig.tls.enabled }}
    {{- $scheme = "https" }}
  {{- end }}
  
  {{- /* Construct the endpoint URL */}}
  {{- if eq $gatewayConfig.service.type "LoadBalancer" }}
    {{- printf "%s://%s" $scheme $domain -}}
  {{- else }}
    {{- if $gatewayConfig.tls.enabled }}
      {{- printf "%s://%s:%v" $scheme $domain $gatewayConfig.service.nodePorts.https -}}
    {{- else }}
      {{- printf "%s://%s:%v" $scheme $domain $gatewayConfig.service.nodePorts.http -}}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
csghub service external endpoint.

Usage: {{ include "common.endpoint.csghub" . }}

Returns: Full URL for the csghub service based on TLS configuration.
*/}}
{{- define "common.endpoint.csghub" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.csghub" .)) -}}
{{- end }}

{{/*
MinIO service external endpoint.

Usage: {{ include "common.endpoint.minio" . }}

Returns: Full URL for the MinIO service based on TLS configuration.
*/}}
{{- define "common.endpoint.minio" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.minio" .)) -}}
{{- end }}

{{/*
Public-facing csghub endpoint.

Usage: {{ include "common.endpoint.public" . }}

Returns: Full URL for the user-facing csghub endpoint based on TLS configuration.
*/}}
{{- define "common.endpoint.public" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.public" .)) -}}
{{- end }}

{{/*
AI Gateway external endpoint.

Usage: {{ include "common.endpoint.aigateway" . }}

Configuration (in global.gateway.external.aigateway):
- domain: Custom domain (e.g., "ai.example.com") - takes precedence if set
- useDomain: true to use dedicated domain (aigateway.<base-domain>)

Returns:
- Custom domain set: Full URL to custom domain (http://ai.example.com)
- useDomain=true:    Full URL to dedicated domain (http://aigateway.<domain>)
- default:           Path-based URL under main domain (http://<csghub-domain>/aigateway)
*/}}
{{- define "common.endpoint.aigateway" }}
{{- $external := .Values.global.gateway.external | default dict }}
{{- $aigatewayConfig := $external.aigateway | default dict }}
{{- $customDomain := $aigatewayConfig.domain | default "" }}
{{- $useDomain := $aigatewayConfig.useDomain | default false }}

{{- if $customDomain }}
{{-   include "common.endpoint" (dict "ctx" . "domain" $customDomain) -}}
{{- else if $useDomain }}
{{-   include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.aigateway" .)) -}}
{{- else }}
{{-   printf "%s/aigateway" (include "common.endpoint.csghub" .) -}}
{{- end }}
{{- end }}

{{/*
AI Gateway endpoint with a chart-level override.

Resolves the aigateway URL the same way as common.endpoint.aigateway, but first
honors an explicit endpoint override in values:

1. If .Values.aigateway.endpoint is set → use it directly
2. If isBuiltIn (bundled with csghub) → use common.endpoint.aigateway
3. Otherwise → use <csghub-endpoint>/aigateway

Usage: {{ include "common.endpoint.aigateway.override" . }}
*/}}
{{- define "common.endpoint.aigateway.override" }}
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
Resolve the external endpoint for any service.

Parameters: same as common.domain.service.

Usage: {{ include "common.endpoint.service" (dict "ctx" . "service" "casdoor") }}
*/}}
{{- define "common.endpoint.service" }}
{{- include "common.endpoint" (dict "ctx" .ctx "domain" (include "common.domain.service" .)) -}}
{{- end }}

{{/*
Service-level endpoint helpers. Each delegates to common.endpoint.service with
the matching domain helper.

Usage: {{ include "common.endpoint.<svc>" . }}
*/}}
{{- define "common.endpoint.casdoor" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "casdoor") -}}
{{- end }}

{{- define "common.endpoint.loki" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "loki") -}}
{{- end }}

{{- define "common.endpoint.prometheus" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "prometheus") -}}
{{- end }}

{{- define "common.endpoint.temporal" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "temporal") -}}
{{- end }}

{{- define "common.endpoint.agenticflow" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "agenticflow") -}}
{{- end }}

{{- define "common.endpoint.csgbot" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "csgbot") -}}
{{- end }}

{{- define "common.endpoint.web" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "web") -}}
{{- end }}

{{- define "common.endpoint.webAPI" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "web" "suffix" "-api") -}}
{{- end }}

{{- define "common.endpoint.dataflow" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "dataflow") -}}
{{- end }}

{{- define "common.endpoint.labelstudio" }}
{{- include "common.endpoint.service" (dict "ctx" . "service" "labelStudio") -}}
{{- end }}

{{- define "common.endpoint.runner" }}
  {{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.runner" .)) -}}
{{- end }}