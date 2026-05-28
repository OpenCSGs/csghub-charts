{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# AI Gateway Domain Helper
# Generates the full domain name for AIGateway service based on configuration
# Usage: {{ include "common.domain.aigateway" . }}
# Returns: aigateway.<base-domain>
*/}}
{{- define "common.domain.aigateway" -}}
{{- $service := include "common.service" (dict "ctx" . "service" "aigateway") | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# AI Gateway External Endpoint Helper
# Generates the complete external access endpoint for AIGateway service
# Usage: {{ include "common.endpoint.aigateway" . }}
# Configuration (in global.gateway.external.aigateway):
#   - domain: Custom domain (e.g., "ai.example.com") - takes precedence if set
#   - useDomain: true to use dedicated domain (aigateway.<base-domain>)
# Returns:
#   - Custom domain set: Full URL to custom domain (http://ai.example.com)
#   - useDomain=true:    Full URL to dedicated domain (http://aigateway.<domain>)
#   - default:           Path-based URL under main domain (http://<csghub-domain>/aigateway)
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