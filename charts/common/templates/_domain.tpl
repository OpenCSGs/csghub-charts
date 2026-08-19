{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Get base domain from external.domain:
- If domain has 3+ segments, return last two segments
- If domain has 2 segments, return as is
*/}}
{{- define "domain.base" }}
  {{- $gateway := .Values.global.gateway | default dict }}
  {{- $external := $gateway.external | default dict }}

  {{- $domain := $external.domain | default "" }}
  {{- $useTop := $external.useTop | default false }}

  {{- if not $domain }}
    {{ fail "external.domain must be set in values.yaml" }}
  {{- end }}

  {{- $baseDomain := $domain }}

  {{- if not $useTop }}
    {{- $parts := splitList "." $domain }}
    {{- if ge (len $parts) 3 }}
      {{- $baseDomain = regexReplaceAll "^[^.]+\\." $domain "" }}
    {{- end }}
  {{- end }}

  {{- $baseDomain -}}
{{- end }}

{{/*
Construct external domain for Gateway resources.

Parameters:
  - context: The Helm context
  - subDomain: Subdomain to prepend to the base domain

Usage: {{ include "common.domain" (dict "ctx" . "sub" "api") }}
*/}}
{{- define "common.domain" }}
  {{- $ctx := .ctx }}
  {{- $subDomain := .sub }}
  {{- $baseDomain := include "domain.base" $ctx }}
  {{- if .sub }}
    {{- printf "%s.%s" .sub $baseDomain -}}
  {{- end }}
{{- end -}}

{{/*
Resolve the csghub service domain from the gateway external configuration.

Usage:
{{ include "common.domain.csghub" . }}

Returns: <global.gateway.external.domain> or "" when not configured.
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
Resolve the MinIO service domain by composing the common subdomain
helpers with the minio service name.

Usage:
{{ include "common.domain.minio" . }}

Returns: <minio-service-name>.<base-domain> or the base domain alone
depending on configuration.
*/}}
{{- define "common.domain.minio" -}}
{{- $service := include "common.service" (dict "ctx" . "service" "minio") | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}