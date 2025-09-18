{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Define the internal domain for csghub
*/}}
{{- define "dataflow.internal.domain" -}}
{{- include "common.names.custom" (list . "dataflow") }}
{{- end }}

{{/*
Define the internal port for csghub
*/}}
{{- define "dataflow.internal.port" -}}
{{- $port := include "csghub.svc.port" "dataflow" }}
{{- if hasKey .Values "dataflow" }}
  {{- if hasKey .Values.dataflow "service" }}
    {{- if hasKey .Values.dataflow.service "port" }}
      {{- $port = .Values.dataflow.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for csghub
*/}}
{{- define "dataflow.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "dataflow.internal.domain" .) (include "dataflow.internal.port" .) -}}
{{- end }}

{{/*
Define the external domain for dataflow
*/}}
{{- define "dataflow.external.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.dataflow "dataflow")) }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for csghub
*/}}
{{- define "dataflow.external.endpoint" -}}
{{- $domain := include "dataflow.external.domain" . }}
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

{{/*
Define the external domain for dataflow
*/}}
{{- define "dataflow.external.public.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.public "public")) }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for csghub
*/}}
{{- define "dataflow.external.public.endpoint" -}}
{{- $domain := include "dataflow.external.public.domain" . }}
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
