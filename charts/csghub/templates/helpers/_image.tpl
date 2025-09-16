{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define image's full path with more robust checks for subCharts
*/}}
{{- define "image.generic.prefix" -}}
{{- $context := index . 0 }}
{{- $globalImage := default dict $context.Values.global.image -}}
{{- $localImage := default dict (index . 1) -}}

{{- $registry := or $globalImage.registry $localImage.registry -}}
{{- $repository := or $localImage.repository $globalImage.repository -}}
{{- $tag := or $localImage.tag $globalImage.tag -}}

{{- if $registry -}}
  {{- if and (regexMatch "^opencsg-registry" $registry) (not (regexMatch "^(opencsghq/|opencsg_public/|public/)" $repository)) }}
    {{- $repository = printf "opencsghq/%s" $repository -}}
  {{- end -}}
{{- end -}}

{{- if and $registry $repository $tag -}}
  {{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- else -}}
  {{- fail "Invalid image configuration - registry, repository and tag are required" -}}
{{- end -}}
{{- end -}}

{{/*
Define image's full path with more robust checks for subCharts with fixed image name
*/}}
{{- define "image.fixed.prefix" -}}
{{- $context := index . 0 -}}
{{- $globalImage := default dict $context.Values.global.image -}}
{{- $localImage := default dict (or $context.Values.image $context.Values.server.image) -}}

{{- $registry := or $globalImage.registry $localImage.registry -}}
{{- $repository := index . 1 -}}

{{- if $registry -}}
  {{- if and (regexMatch "^opencsg-registry" $registry) (not (regexMatch "^(opencsghq/|opencsg_public/|public/)" $repository)) }}
    {{- $repository = printf "opencsghq/%s" $repository -}}
  {{- end -}}
{{- end -}}

{{- if and $registry $repository -}}
  {{- printf "%s/%s" $registry $repository -}}
{{- else -}}
  {{- fail "Invalid image configuration - registry, repository are required" -}}
{{- end -}}
{{- end -}}
