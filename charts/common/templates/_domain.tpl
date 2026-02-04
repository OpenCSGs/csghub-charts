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
  {{- $domain := "" }}
  {{- if hasKey .Values.global.gateway "external" }}
    {{- if hasKey .Values.global.gateway.external "domain" }}
      {{- $domain = .Values.global.gateway.external.domain }}
    {{- end }}
  {{- end }}

  {{- if not $domain }}
    {{ fail "external.domain must be set in values.yaml" }}
  {{- end }}

  {{- $parts := splitList "." $domain }}
  {{- if ge (len $parts) 3 }}
    {{- regexReplaceAll "^[^.]+\\." $domain "" -}}
  {{- else }}
    {{- $domain }}
  {{- end }}
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