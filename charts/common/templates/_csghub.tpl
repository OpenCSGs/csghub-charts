{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
csghub hub API token (128 hex), persisted in the master Secret under
"csghub-token" so it survives upgrades.
*/}}
{{- define "csghub.api.token" }}
  {{- include "common.secret.value" (list . "csghub-token" 128) -}}
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