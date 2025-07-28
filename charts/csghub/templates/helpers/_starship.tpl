{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the external domain for starship
*/}}
{{- define "starship.external.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.starship "starship")) }}
{{- if hasKey .Values.global.ingress "useTop" }}
{{- if .Values.global.ingress.useTop }}
{{- $domain = .Values.global.ingress.domain }}
{{- end }}
{{- end }}
{{- $domain -}}
{{- end }}

{{/*
Define the external api domain for starship
*/}}
{{- define "starship.external.api.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.starshipAPI "starship-api")) }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for starship
*/}}
{{- define "starship.external.endpoint" -}}
{{- $domain := include "starship.external.domain" . }}
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
Define the external endpoint for starship
*/}}
{{- define "starship.external.api.endpoint" -}}
{{- $domain := include "starship.external.api.domain" . }}
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
Define if starship enabled
*/}}
{{- define "starship.enabled" -}}
{{- include "csghub.starship.enabled" . -}}
{{- end }}
