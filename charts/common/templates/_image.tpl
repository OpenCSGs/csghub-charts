{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Internal: given a (possibly empty) registry hint and an image/repo string,
compute the final registry + image with OpenCSG path adjustment.

Behaviour:
- If registry is empty, parse it from the image string ("host/path" → host).
- If the resolved registry matches the OpenCSG registry and the image path
  is not already prefixed with one of the public prefixes
  (opencsghq/, opencsg_public/, public/), prepend "opencsghq/".

Parameters:
- registry: registry hint (may be empty)
- image:    image or repository string (will be mutated when parsed)

Returns: YAML dict {registry: ..., image: ...}.
*/}}
{{- define "common.image._resolve" }}
{{- $registry := .registry }}
{{- $image := .image }}
{{- if not $registry }}
  {{- $registry = regexFind "^[^/]+" $image }}
  {{- if $registry }}
    {{- $image = trimPrefix (printf "%s/" $registry) $image }}
  {{- end }}
{{- end }}
{{- if and $registry (regexMatch "^opencsg-registry" $registry) }}
  {{- if not (regexMatch "^(opencsghq/|opencsg_public/|public/)" $image) }}
    {{- $image = printf "opencsghq/%s" $image }}
  {{- end }}
{{- end }}
{{- dict "registry" $registry "image" $image | toYaml -}}
{{- end }}

{{/*
Generate full image path with robust subchart support

Usage:
{{ include "common.image" (list . .Values.image) }}

Parameters:
- context: Chart context (usually .)
- localImage: Local image configuration values

Returns: Full image path in format "registry/repository:tag"
*/}}
{{- define "common.image" }}
  {{- $ctx := index . 0 }}
  {{- $localImage := default dict (index . 1) }}
  {{- $globalImage := default dict $ctx.Values.global.image }}

  {{- /* Merge global and local image configuration with priority */}}
  {{- $registry := or $localImage.registry $globalImage.registry }}
  {{- $repository := or $localImage.repository $globalImage.repository }}
  {{- $tag := or $localImage.tag $globalImage.tag }}

  {{- if eq $globalImage.registryPolicy "force" }}
    {{- $registry = or $globalImage.registry "opencsg-registry.cn-beijing.cr.aliyuncs.com" }}
  {{- end }}

  {{- $resolved := include "common.image._resolve" (dict "registry" $registry "image" $repository) | fromYaml }}
  {{- $registry = $resolved.registry }}
  {{- $repository = $resolved.image }}

  {{- /* Validate and return full image path */}}
  {{- if and $registry $repository $tag }}
    {{- printf "%s/%s:%s" $registry $repository $tag -}}
  {{- else }}
    {{ fail "Invalid image configuration - registry, repository and tag are required" }}
  {{- end }}
{{- end }}

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
{{- define "common.image.fixed" }}
  {{- $ctx := .ctx }}
  {{- $service := .service }}
  {{- $image := .image }}
  {{- $globalImage := default dict $ctx.Values.global.image }}

  {{- /* Support multiple image configuration paths */}}
  {{- $localImage := dict }}
  {{- if index $ctx.Values $service }}
    {{- if index $ctx.Values $service "image" }}
      {{- $localImage = index $ctx.Values $service "image" }}
    {{- end }}
  {{- else }}
    {{- $localImage = $ctx.Values.image }}
  {{- end }}

  {{- $registry := or $localImage.registry $globalImage.registry }}
  {{- if eq $globalImage.registryPolicy "force" }}
    {{- $registry = or $globalImage.registry "opencsg-registry.cn-beijing.cr.aliyuncs.com" }}
  {{- end }}

  {{- $resolved := include "common.image._resolve" (dict "registry" $registry "image" $image) | fromYaml }}
  {{- $registry = $resolved.registry }}
  {{- $image = $resolved.image }}

  {{- /* Validate and return full image path */}}
  {{- if and $registry $image }}
    {{- printf "%s/%s" $registry $image }}
  {{- else }}
    {{ fail "Invalid image configuration - registry and image are required" }}
  {{- end }}
{{- end }}

{{/*
Construct image tag with edition suffix
Usage: {{ include "common.image.tag" (dict "ctx" . "tag" "v1.8.0") }}
*/}}
{{- define "common.image.tag" }}
{{- $tag := .tag }}
{{- $edition := (.ctx.Values.global.edition | default "ee") }}
{{- if and (regexMatch "^v[0-9]+\\.[0-9]+\\.[0-9]+$" $tag) (or (eq $edition "ce") (eq $edition "ee")) (not (regexMatch "(-ce|-ee)$" $tag)) }}
  {{- printf "%s-%s" $tag $edition -}}
{{- else }}
  {{- $tag -}}
{{- end }}
{{- end -}}