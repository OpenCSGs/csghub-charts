{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for csghub
*/}}
{{- define "loki.internal.domain" -}}
{{- include "common.names.custom" (list . "loki") }}
{{- end }}

{{/*
Define the internal port for csghub
*/}}
{{- define "loki.internal.port" -}}
{{- $port := "3100" }}
{{- if hasKey .Values.global "loki" }}
  {{- if hasKey .Values.global.loki "service" }}
    {{- if hasKey .Values.global.loki.service "port" }}
      {{- $port = .Values.global.loki.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for csghub
*/}}
{{- define "loki.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "loki.internal.domain" .) (include "loki.internal.port" .) -}}
{{- end }}

{{/*
Define the external domain for loki
*/}}
{{- define "loki.external.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.loki "loki")) }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for csghub
*/}}
{{- define "loki.external.endpoint" -}}
{{- $domain := include "loki.external.domain" . }}
{{- if eq .Values.global.ingress.service.type "NodePort" }}
{{- if .Values.global.ingress.tls.enabled -}}
{{- printf "https://%s:%s" $domain "30443" -}}
{{- else }}
{{- printf "http://%s:%s" $domain "30080" -}}
{{- end }}
{{- else }}
{{- if .Values.global.ingress.tls.enabled -}}
{{- printf "https://%s" $domain -}}
{{- else }}
{{- printf "http://%s" $domain -}}
{{- end }}
{{- end }}
{{- end }}
