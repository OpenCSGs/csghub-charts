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