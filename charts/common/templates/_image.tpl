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
  {{- $registry := or $localImage.registry $globalImage.registry -}}
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
{{ include "common.image.fixed" (list . "image-name") }}

Parameters:
- context: Chart context (usually .)
- repository: Fixed image repository name

Returns: Full image path in format "registry/repository"
*/}}
{{- define "common.image.fixed" -}}
  {{- $context := index . 0 -}}
  {{- $repository := index . 1 -}}
  {{- $globalImage := default dict $context.Values.global.image -}}

  {{- /* Support multiple image configuration paths */ -}}
  {{- $localImage := dict -}}
  {{- if $context.Values.image -}}
    {{- $localImage = $context.Values.image -}}
  {{- else if $context.Values.server.image -}}
    {{- $localImage = $context.Values.server.image -}}
  {{- end -}}

  {{- $registry := or $localImage.registry $globalImage.registry -}}

  {{- /* Adjust repository path for OpenCSG registry */ -}}
  {{- if and $registry (regexMatch "^opencsg-registry" $registry) -}}
    {{- if not (regexMatch "^(opencsghq/|opencsg_public/|public/)" $repository) -}}
      {{- $repository = printf "opencsghq/%s" $repository -}}
    {{- end -}}
  {{- end -}}

  {{- /* Validate and return full image path */ -}}
  {{- if and $registry $repository -}}
    {{- printf "%s/%s" $registry $repository -}}
  {{- else -}}
    {{- fail "Invalid image configuration - registry and repository are required" -}}
  {{- end -}}
{{- end -}}