{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for casdoor
*/}}
{{- define "casdoor.internal.domain" -}}
{{- include "common.names.custom" (list . "casdoor") }}
{{- end }}

{{/*
Define the internal port for casdoor
*/}}
{{- define "casdoor.internal.port" -}}
{{- $port := "8000" }}
{{- if hasKey .Values.global "casdoor" }}
  {{- if hasKey .Values.global.casdoor "service" }}
    {{- if hasKey .Values.global.casdoor.service "port" }}
      {{- $port = .Values.global.casdoor.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for casdoor
*/}}
{{- define "casdoor.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "casdoor.internal.domain" .) (include "casdoor.internal.port" .) -}}
{{- end }}

{{/*
Define the external http domain for casdoor
*/}}
{{- define "casdoor.external.domain" -}}
{{- include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.casdoor "casdoor")) }}
{{- end }}

{{/*
Define the external endpoint for casdoor
*/}}
{{- define "casdoor.external.endpoint" -}}
{{- $domain := include "casdoor.external.domain" . }}
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
Random Password for which password not set
*/}}
{{- define "casdoor.initPass" -}}
{{- printf "%s@%s" (now | date "15/04") . | sha256sum | b64enc | trunc 24 -}}
{{- end }}