{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the external domain for csgship
*/}}
{{- define "csgship.external.domain" -}}
{{- $domain := include "global.domain" (list . "csgship") }}
{{- if hasKey .Values.global.ingress "useTop" }}
{{- if .Values.global.ingress.useTop }}
{{- $domain = .Values.global.ingress.domain }}
{{- end }}
{{- end }}
{{- $domain -}}
{{- end }}

{{/*
Define the external api domain for csgship
*/}}
{{- define "csgship.external.api.domain" -}}
{{- $domain := include "global.domain" (list . "csgship-api") }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for csgship
*/}}
{{- define "csgship.external.endpoint" -}}
{{- $domain := include "csgship.external.domain" . }}
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
Define the external endpoint for csgship
*/}}
{{- define "csgship.external.api.endpoint" -}}
{{- $domain := include "csgship.external.api.domain" . }}
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