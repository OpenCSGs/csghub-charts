{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Construct the external endpoint for csghub with flexible configuration.

Priority:
1. Service-specific ingress configuration
2. Global ingress configuration

Parameters can be passed as a dict with:
- ctx: The Helm context
- service: Service-specific values (optional)
- domain: Domain for the endpoint

Usage:
{{ include "common.endpoint" (dict "ctx" . "service" .Values.webapp "domain" "app.example.com") }}
*/}}
{{- define "common.endpoint" -}}
  {{- /* Parse parameters */ -}}
  {{- $ctx := .ctx -}}
  {{- $service := .service | default dict -}}
  {{- $domain := .domain -}}

  {{- /* Get merged ingress configuration using common.ingress.config */ -}}
  {{- $ingressConfig := include "common.ingress.config" (dict "service" $service "global" $ctx) | fromYaml -}}
  
  {{- /* Determine protocol and port based on configuration */ -}}
  {{- $protocol := "http" -}}
  {{- $port := "" -}}
  
  {{- if $ingressConfig.tls.enabled -}}
    {{- $protocol = "https" -}}
  {{- end -}}
  
  {{- if eq $ingressConfig.service.type "NodePort" -}}
    {{- if $ingressConfig.tls.enabled -}}
      {{- $port = "30443" -}}
    {{- else -}}
      {{- $port = "30080" -}}
    {{- end -}}
  {{- end -}}
  
  {{- /* Construct the endpoint URL */ -}}
  {{- if $port -}}
    {{- printf "%s://%s:%s" $protocol $domain $port -}}
  {{- else -}}
    {{- printf "%s://%s" $protocol $domain -}}
  {{- end -}}
{{- end -}}