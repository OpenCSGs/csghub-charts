{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate global unique HUB_SERVER_API_TOKEN

Usage:
{{ include "csghub.api.token" . }}

Parameters:
- ctx: Global context (e.g., .)

Returns: Unique API token string that changes on every installation
*/}}
{{- define "csghub.api.token" }}
  {{- $ctx := . }}

  {{- /* Generate random seed for uniqueness across installations */}}
  {{- $seed := now | date "200601021504" }}

  {{- /* Create unique hashes combining release info with random seed */}}
  {{- $namespaceHash := (printf "%s-%s" $ctx.Release.Namespace $seed | sha256sum) }}
  {{- $nameHash := (printf "%s-%s" $ctx.Release.Name $seed | sha256sum) }}

  {{- /* Combine hashes to form final token */}}
  {{- printf "%s%s" $namespaceHash $nameHash }}
{{- end }}

{{/*
Resolve service image with proper tag
Usage:
  {{ include "csghub.service.image" (dict "ctx" . "service" .Values.rproxy) }}
*/}}
{{- define "csghub.service.image" }}
{{- $service := .service }}
{{- $ctx := .ctx }}

{{- $baseImage := deepCopy (default (dict) $ctx.Values.image) }}
{{- $serviceImage := deepCopy (default (dict) $service.image) }}

{{- $tag := or (dig "image" "tag" "" $service) $baseImage.tag $ctx.Values.global.image.tag }}
{{- $finalTag := include "common.image.tag" (dict "ctx" $ctx "tag" $tag) }}

{{- $mergedImage := mergeOverwrite $baseImage $serviceImage }}
{{- $_ := set $mergedImage "tag" $finalTag }}

{{- $mergedImage | toYaml -}}
{{- end }}