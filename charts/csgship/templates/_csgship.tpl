{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Resolve service image with proper tag
Usage:
  {{ include "csgship.service.image" (dict "ctx" . "service" .Values.rproxy) }}
*/}}
{{- define "csgship.service.image" }}
{{- $ctx := .ctx }}
{{- $service := .service }}

{{- $baseImage := deepCopy (default (dict) $ctx.Values.image) }}
{{- $serviceImage := deepCopy (default (dict) $service.image) }}

{{- $mergedImage := mergeOverwrite $baseImage $serviceImage }}

{{- $mergedImage | toYaml -}}
{{- end }}