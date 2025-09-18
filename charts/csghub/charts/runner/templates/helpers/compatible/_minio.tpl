{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for minio
*/}}
{{- define "minio.internal.domain" -}}
{{- include "common.names.custom" (list . "minio") }}
{{- end }}

{{/*
Define the internal port for minio
*/}}
{{- define "minio.internal.port" -}}
{{- $port := "9000" }}
{{- if hasKey .Values.global "minio" }}
  {{- if hasKey .Values.global.minio "service" }}
    {{- if hasKey .Values.global.minio.service "port" }}
      {{- $port = .Values.global.minio.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for minio
*/}}
{{- define "minio.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "minio.internal.domain" .) (include "minio.internal.port" .) -}}
{{- end }}

{{/*
Define the external domain for minio
*/}}
{{- define "minio.external.domain" -}}
{{- include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.minio "minio")) }}
{{- end }}

{{/*
Define the external endpoint for minio
*/}}
{{- define "minio.external.endpoint" -}}
{{- $domain := include "minio.external.domain" . }}
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
