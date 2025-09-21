{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Define the internal domain for csghub
*/}}
{{- define "label-studio.internal.domain" -}}
{{- include "common.names.custom" (list . "label-studio") }}
{{- end }}

{{/*
Define the internal port for csghub
*/}}
{{- define "label-studio.internal.port" -}}
{{- $port := include "csghub.svc.port" "label-studio" }}
{{- if hasKey .Values "label-studio" }}
  {{- if hasKey .Values.labelStudio "service" }}
    {{- if hasKey .Values.labelStudio.service "port" }}
      {{- $port = .Values.labelStudio.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for csghub
*/}}
{{- define "label-studio.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "label-studio.internal.domain" .) (include "label-studio.internal.port" .) -}}
{{- end }}

{{/*
Define the external domain for label-studio
*/}}
{{- define "label-studio.external.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.labelStudio "label-studio")) }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for csghub
*/}}
{{- define "label-studio.external.endpoint" -}}
{{- $domain := include "label-studio.external.domain" . }}
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
Define the external domain for label-studio
*/}}
{{- define "label-studio.external.public.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.public "public")) }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for csghub
*/}}
{{- define "label-studio.external.public.endpoint" -}}
{{- $domain := include "label-studio.external.public.domain" . }}
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
