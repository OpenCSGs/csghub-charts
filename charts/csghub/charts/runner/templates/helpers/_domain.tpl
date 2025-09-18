{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the external domain
*/}}
{{- define "global.domain" -}}
{{- $ctx := index . 0 }}
{{- $subDomain := index . 1 }}
{{- if hasKey $ctx.Values.global "ingress" }}
    {{- if hasKey $ctx.Values.global.ingress "domain" }}
      {{- $domain := $ctx.Values.global.ingress.domain }}
      {{- if $domain }}
        {{- printf "%s.%s" $subDomain $domain }}
      {{- else }}
        {{ fail "A valid domain entry (like example.com) is required!" }}
      {{- end }}
    {{- else }}
      {{ fail "Global domain is not defined!" }}
    {{- end }}
  {{- end }}
{{- end }}