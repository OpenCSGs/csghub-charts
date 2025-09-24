{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Construct the external endpoint for csghub with flexible configuration.

Priority:
1. Service-specific ingress configuration (in .Values.ingress)
2. Global ingress configuration (in .Values.global.ingress)

Parameters can be passed as a dict with:
- context: The Helm context
- subDomain: Subdomain for the endpoint (optional, passed to csghub.external.domain)

Usage: 
1. {{ include "common.endpoint" . }}
2. {{ include "common.endpoint" (dict "ctx" . "domain" "test.example.com") }}
*/}}
{{- define "common.endpoint" -}}
  {{- /* Parse parameters */ -}}
  {{- $ctx := .ctx -}}
  {{- $domain := .domain -}}
  
  {{- /* Determine which ingress configuration to use */ -}}
  {{- $ingressConfig := $ctx.Values.ingress -}}
  {{- if not $ingressConfig -}}
    {{- $ingressConfig = $ctx.Values.global.ingress -}}
  {{- else -}}
    {{- /* If service has ingress config but missing some fields, fallback to global */ -}}
    {{- if not (hasKey $ingressConfig "tls") -}}
      {{- $ingressConfig = merge $ingressConfig (dict "tls" $ctx.Values.global.ingress.tls) -}}
    {{- end -}}
    {{- if not (hasKey $ingressConfig.service "type") -}}
      {{- $ingressConfig = merge $ingressConfig (dict "service" $ctx.Values.global.ingress.service) -}}
    {{- end -}}
  {{- end -}}
  
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