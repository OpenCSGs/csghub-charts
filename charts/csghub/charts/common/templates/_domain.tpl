{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Construct external domain for ingress resources.

Parameters:
  - context: The Helm context
  - subDomain: Subdomain to prepend to the base domain

Usage: {{ include "common.domain" (dict "ctx" . "sub" "api") }}
*/}}
{{- define "common.domain" -}}
  {{- $ctx := .ctx -}}
  {{- $subDomain := .sub -}}

  {{- if hasKey $ctx.Values.global "ingress" -}}
    {{- if hasKey $ctx.Values.global.ingress "domain" -}}
      {{- $domain := $ctx.Values.global.ingress.domain -}}
      {{- if $domain -}}
        {{- printf "%s.%s" $subDomain $domain -}}
      {{- else -}}
        {{- fail "A valid domain entry (like example.com) is required in global.ingress.domain!" -}}
      {{- end -}}
    {{- else -}}
      {{- fail "Global domain is not defined in global.ingress.domain!" -}}
    {{- end -}}
  {{- else -}}
    {{- fail "Global ingress configuration is missing!" -}}
  {{- end -}}
{{- end -}}