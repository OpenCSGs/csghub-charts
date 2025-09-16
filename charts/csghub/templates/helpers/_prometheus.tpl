{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for csghub
*/}}
{{- define "prometheus.internal.domain" -}}
{{- include "common.names.custom" (list . "prometheus") }}
{{- end }}

{{/*
Define the internal port for csghub
*/}}
{{- define "prometheus.internal.port" -}}
{{- $port := "80" }}
{{- if hasKey .Values.global "prometheus" }}
  {{- if hasKey .Values.global.prometheus "service" }}
    {{- if hasKey .Values.global.prometheus.service "port" }}
      {{- $port = .Values.global.prometheus.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for csghub
*/}}
{{- define "prometheus.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "prometheus.internal.domain" .) (include "prometheus.internal.port" .) -}}
{{- end }}

{{/*
Define the external domain for prometheus
*/}}
{{- define "prometheus.external.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.prometheus "prometheus")) }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for csghub
*/}}
{{- define "prometheus.external.endpoint" -}}
{{- $domain := include "prometheus.external.domain" . }}
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
