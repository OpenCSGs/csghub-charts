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

{{- $registry := $localImage.registry -}}
{{- $repository := $localImage.repository -}}
{{- $tag := $localImage.tag -}}

{{- if $globalImage.registry -}}
  {{- $registry = $globalImage.registry -}}
  {{- if and (regexMatch "^opencsg-registry" $registry) (not (regexMatch "^(opencsghq|opencsg_public|public)" $repository)) }}
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
{{- $localImage := default dict (or $context.Values.image $context.Values.csghub.server.image) -}}

{{- $registry := $localImage.registry -}}
{{- $repository := index . 1 -}}

{{- if $globalImage.registry -}}
  {{- $registry = $globalImage.registry -}}
  {{- if and (regexMatch "^opencsg-registry" $registry) (not (regexMatch "^opencsghq" $repository)) }}
    {{- $repository = printf "opencsghq/%s" $repository -}}
  {{- end -}}
{{- end -}}

{{- if and $registry $repository -}}
  {{- printf "%s/%s" $registry $repository -}}
{{- else -}}
  {{- fail "Invalid image configuration - registry, repository are required" -}}
{{- end -}}
{{- end -}}
