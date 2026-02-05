{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate normalized service configuration

Usage:
  # Mode 1: Specific service
  {{ include "common.service" (dict "ctx" . "service" "server") }}

  # Mode 2: Global Values
  {{ include "common.service" . }}
*/}}
{{- define "common.service" }}
{{- if and (kindIs "map" .) (hasKey . "ctx") }}
  {{- /* Mode 1: dict with explicit global */}}
  {{- $ctx := .ctx }}
  {{- $hasService := hasKey . "service" }}

  {{- if $hasService }}
    {{- $serviceType := .service }}
    {{- $svc := index $ctx.Values $serviceType | default dict }}
    {{- $defaultName := kebabcase $serviceType }}
    {{- $name := dig "name" $defaultName $svc }}
    {{- $merged := mergeOverwrite (dict "name" $name) $svc }}
    {{- toYaml $merged -}}
  {{- else }}
    {{- $svc := merge (dict) $ctx.Values }}
    {{- $name := dig "name" "global" $svc }}
    {{- $merged := mergeOverwrite (dict "name" $name) $svc }}
    {{- toYaml $merged -}}
  {{- end }}
{{- else }}
  {{- /* Mode 2: called directly with . */}}
  {{- $svc := merge (dict) .Values }}
  {{- $name := dig "name" .Release.Name $svc }}
  {{- $merged := mergeOverwrite (dict "name" $name) $svc }}
  {{- toYaml $merged -}}
{{- end }}
{{- end -}}