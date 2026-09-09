{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
Define the memmachine image string.
Supports optional registry prefixing for "registry.opencsg.com".
Returns registry/repository:tag or repository:tag.
*/ -}}
{{- define "memmachine.image" -}}
{{- $registry := .image.registry | default .global.image.registry -}}
{{- $repository := .image.repository -}}
{{- if and $registry (include "common.registry.isopencsg" $registry) -}}
  {{- if not (regexMatch "^(opencsghq/|opencsg_public/|public/)" $repository) -}}
    {{- $repository = printf "opencsghq/%s" $repository -}}
  {{- end -}}
{{- end -}}
{{- $tag := .image.tag -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end -}}