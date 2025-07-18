{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the external domain for csghub
*/}}
{{- define "csghub.external.domain" -}}
{{- $domain := include "global.domain" (list . "csghub") }}
{{- if hasKey .Values.global.ingress "useTop" }}
{{- if .Values.global.ingress.useTop }}
{{- $domain = .Values.global.ingress.domain }}
{{- end }}
{{- end }}
{{- $domain -}}
{{- end }}

{{/*
Define the external public domain for csghub
*/}}
{{- define "csghub.external.public.domain" -}}
{{- include "global.domain" (list . "public") -}}
{{- end }}

{{/*
Define the external endpoint for csghub
*/}}
{{- define "csghub.external.endpoint" -}}
{{- $domain := include "csghub.external.domain" . }}
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
Define the external public endpoint for csghub
*/}}
{{- define "csghub.external.public.endpoint" -}}
{{- $domain := include "csghub.external.public.domain" . }}
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
Get the edition suffix for image tags
*/}}
{{- define "csghub.edition.suffix" -}}
{{- $edition := .Values.global.edition | default "ee" -}}
{{- if has $edition (list "ce" "ee") -}}
{{- $edition -}}
{{- end -}}
{{- end -}}

{{/*
Construct image tag with edition suffix
Usage: {{ include "csghub.image.tag" (dict "tag" "v1.8.0" "context" .) }}
*/}}
{{- define "csghub.image.tag" -}}
{{- $tag := .tag -}}
{{- $context := .context -}}
{{- $edition := include "csghub.edition.suffix" $context -}}
{{- if contains "-ce" $tag -}}
{{- $tag -}}
{{- else if contains "-ee" $tag -}}
{{- $tag -}}
{{- else -}}
{{- printf "%s" $tag -}}
{{- end -}}
{{- end }}

{{/*
Check if starship should be enabled based on edition and explicit configuration
Starship is only enabled when:
1. global.edition is "ee" (Enterprise Edition)
2. starship.enabled is explicitly set to true
*/}}
{{- define "csghub.starship.enabled" -}}
{{- $edition := .Values.global.edition | default "ee" -}}
{{- $starshipEnabled := false -}}
{{- if eq $edition "ee" -}}
{{- if hasKey .Values "starship" -}}
{{- if hasKey .Values.starship "enabled" -}}
{{- if .Values.starship.enabled -}}
{{- $starshipEnabled = true -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $starshipEnabled -}}
{{- end }}

{{/*
Define global unique HUB_SERVER_API_TOKEN
*/}}
{{- define "server.hub.api.token" -}}
{{- $namespaceHash := (.Release.Namespace | sha256sum) }}
{{- $nameHash := (.Release.Name | sha256sum) }}
{{- printf "%s%s" $namespaceHash $nameHash -}}
{{- end }}