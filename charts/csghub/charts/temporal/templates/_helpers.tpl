{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for temporal
*/}}
{{- define "temporal.internal.domain" -}}
{{- include "common.names.custom" (list . "temporal") }}
{{- end }}

{{/*
Define the internal port for temporal
*/}}
{{- define "temporal.internal.port" -}}
{{- $port := "7233" }}
{{- if hasKey .Values.global "temporal" }}
  {{- if hasKey .Values.global.temporal "service" }}
    {{- if hasKey .Values.global.temporal.service "port" }}
      {{- $port = .Values.global.temporal.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for temporal
*/}}
{{- define "temporal.internal.endpoint" -}}
{{- printf "%s:%s" (include "temporal.internal.domain" .) (include "temporal.internal.port" .) -}}
{{- end }}

{{/*
Define the external domain for temporal
*/}}
{{- define "temporal.external.domain" -}}
{{- include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.temporal "temporal")) }}
{{- end }}

{{/*
Define the external endpoint for temporal
*/}}
{{- define "temporal.external.endpoint" -}}
{{- $domain := include "temporal.external.domain" . }}
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