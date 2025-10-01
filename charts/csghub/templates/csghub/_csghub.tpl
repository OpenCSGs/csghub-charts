{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# csghub Domain Helper
# Generates the full domain name for csghub service based on configuration
# Usage: {{ include "common.domain.csghub" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.csghub" -}}
{{- $sub := .Release.Name }}
{{- if .Values.global.ingress.useTop }}
{{- $sub = "" }}
{{- end }}
{{- include "common.domain" (dict "ctx" . "sub" $sub) -}}
{{- end }}

{{/*
# csghub Public Domain Helper
# Generates the full domain name for csghub service based on configuration
# Usage: {{ include "common.domain.public" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.public" -}}
{{- $sub := "public" }}
{{- if .Values.global.ingress.useTop }}
{{- $sub = "" }}
{{- end }}
{{- include "common.domain" (dict "ctx" . "sub" $sub) -}}
{{- end }}

{{/*
# csghub External Endpoint Helper
# Generates the complete external access endpoint for csghub service
# Usage: {{ include "external.endpoint.csghub" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.csghub" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.csghub" .)) -}}
{{- end }}

{{/*
Generate global unique HUB_SERVER_API_TOKEN

Usage:
{{ include "csghub.api.token" . }}

Parameters:
- global: Global context (e.g., .)

Returns: Unique API token string that changes on every installation
*/}}
{{- define "csghub.api.token" -}}
  {{- $global := . -}}

  {{- /* Generate random seed for uniqueness across installations */ -}}
  {{- $seed := randAlphaNum 8 -}}

  {{- /* Create unique hashes combining release info with random seed */ -}}
  {{- $namespaceHash := (printf "%s-%s" $global.Release.Namespace $seed | sha256sum) -}}
  {{- $nameHash := (printf "%s-%s" $global.Release.Name $seed | sha256sum) -}}

  {{- /* Combine hashes to form final token */ -}}
  {{- printf "%s%s" $namespaceHash $nameHash -}}
{{- end -}}

{{/*
Resolve service image with proper tag
Usage:
  {{ include "csghub.service.image" (dict "service" .Values.rproxy "context" .) }}
*/}}
{{- define "csghub.service.image" -}}
{{- $service := .service -}}
{{- $context := .context -}}
{{- $tag := or (dig "image" "tag" "" $service) $context.Values.image.tag $context.Values.global.image.tag -}}
{{- $finalTag := include "common.image.tag" (dict "tag" $tag "context" $context) -}}
{{- $_ := set $context.Values.image "tag" $finalTag -}}
{{- $image := mergeOverwrite $context.Values.image (default dict $service.image) -}}
{{- $image | toYaml -}}
{{- end -}}