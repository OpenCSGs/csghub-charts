{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate full image path with robust subchart support

Usage:
{{ include "common.image" (list . .Values.image) }}

Parameters:
- context: Chart context (usually .)
- localImage: Local image configuration values

Returns: Full image path in format "registry/repository:tag"
*/}}
{{- define "common.image" -}}
  {{- $context := index . 0 -}}
  {{- $localImage := default dict (index . 1) -}}
  {{- $globalImage := default dict $context.Values.global.image -}}

  {{- /* Merge global and local image configuration with priority */ -}}
  {{- $registry := or $globalImage.registry $localImage.registry -}}
  {{- $repository := or $localImage.repository $globalImage.repository -}}
  {{- $tag := or $localImage.tag $globalImage.tag -}}

  {{- /* Adjust repository path for OpenCSG registry */ -}}
  {{- if and $registry (regexMatch "^opencsg-registry" $registry) -}}
    {{- if not (regexMatch "^(opencsghq/|opencsg_public/|public/)" $repository) -}}
      {{- $repository = printf "opencsghq/%s" $repository -}}
    {{- end -}}
  {{- end -}}

  {{- /* Validate and return full image path */ -}}
  {{- if and $registry $repository $tag -}}
    {{- printf "%s/%s:%s" $registry $repository $tag -}}
  {{- else -}}
    {{- fail "Invalid image configuration - registry, repository and tag are required" -}}
  {{- end -}}
{{- end -}}

{{/*
Generate full image path with fixed image name

Usage:
{{ include "common.image.fixed" (dict "ctx" . "service" "minio" "image" "busybox:latest") }}

Parameters:
- ctx: Chart context (usually .)
- service: Service name (e.g., "minio")
- image: Fixed image repository name (e.g., "busybox:latest")

Returns: Full image path in format "registry/repository"
*/}}
{{- define "common.image.fixed" -}}
  {{- $ctx := .ctx -}}
  {{- $service := .service -}}
  {{- $image := .image -}}
  {{- $globalImage := default dict $ctx.Values.global.image -}}

  {{- /* Support multiple image configuration paths */ -}}
  {{- $localImage := dict -}}
  {{- if index $ctx.Values $service -}}
    {{- if index $ctx.Values $service "image" -}}
      {{- $localImage = index $ctx.Values $service "image" -}}
    {{- end -}}
  {{- else }}
    {{- $localImage = $ctx.Values.image }}
  {{- end -}}

  {{- $registry := or $globalImage.registry $localImage.registry -}}

  {{- /* Adjust repository path for OpenCSG registry */ -}}
  {{- if and $registry (regexMatch "^opencsg-registry" $registry) -}}
    {{- if not (regexMatch "^(opencsghq/|opencsg_public/|public/)" $image) -}}
      {{- $image = printf "opencsghq/%s" $image -}}
    {{- end -}}
  {{- end -}}

  {{- /* Validate and return full image path */ -}}
  {{- if and $registry $image -}}
    {{- printf "%s/%s" $registry $image -}}
  {{- else -}}
    {{- fail "Invalid image configuration - registry and image are required" -}}
  {{- end -}}
{{- end -}}

{{/*
Construct image tag with edition suffix
Usage: {{ include "common.image.tag" (dict "tag" "v1.8.0" "context" .) }}
*/}}
{{- define "common.image.tag" -}}
{{- $tag := .tag -}}
{{- $edition := (.context.Values.global.edition | default "ee") -}}
{{- if and (or (eq $edition "ce") (eq $edition "ee")) (not (regexMatch "(-ce|-ee)$" $tag)) -}}
  {{- printf "%s-%s" $tag $edition -}}
{{- else -}}
  {{- $tag -}}
{{- end -}}
{{- end -}}