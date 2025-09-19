{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Define the internal domain for csghub
*/}}
{{- define "csghub.internal.domain" -}}
{{- include "common.names.custom" (list . "server") }}
{{- end }}

{{/*
Define the internal port for csghub
*/}}
{{- define "csghub.internal.port" -}}
{{- $port := include "csghub.svc.port" "server" }}
{{- if hasKey .Values.global "server" }}
  {{- if hasKey .Values.global.server "service" }}
    {{- if hasKey .Values.global.server.service "port" }}
      {{- $port = .Values.global.server.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for csghub
*/}}
{{- define "csghub.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "csghub.internal.domain" .) (include "csghub.internal.port" .) -}}
{{- end }}

{{/*
Define the external domain for csghub
*/}}
{{- define "csghub.external.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.portal "csghub")) }}
{{- if hasKey .Values.global.ingress "useTop" }}
{{- if .Values.global.ingress.useTop }}
{{- $domain = .Values.global.ingress.domain }}
{{- end }}
{{- end }}
{{- $domain -}}
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
{{- if has $edition (list "ce" "ee") -}}
{{- if regexMatch "(-ce|-ee)$" $tag }}
{{- $tag -}}
{{- else }}
{{- printf "%s-%s" $tag $edition -}}
{{- end -}}
{{- else }}
{{- $tag -}}
{{- end -}}
{{- end -}}

{{/*
Check if csgship should be enabled based on edition and explicit configuration
csgship is only enabled when:
1. global.edition is "ee" (Enterprise Edition)
2. csgship.enabled is explicitly set to true
*/}}
{{- define "csghub.csgship.enabled" -}}
{{- $edition := .Values.global.edition | default "ee" -}}
{{- $csgshipEnabled := false -}}
{{- if eq $edition "ee" -}}
{{- if hasKey .Values "csgship" -}}
{{- if hasKey .Values.csgship "enabled" -}}
{{- if .Values.csgship.enabled -}}
{{- $csgshipEnabled = true -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $csgshipEnabled -}}
{{- end }}

{{/*
Define global unique HUB_SERVER_API_TOKEN
*/}}
{{- define "server.hub.api.token" -}}
{{- $namespaceHash := (.Release.Namespace | sha256sum) }}
{{- $nameHash := (.Release.Name | sha256sum) }}
{{- printf "%s%s" $namespaceHash $nameHash -}}
{{- end }}