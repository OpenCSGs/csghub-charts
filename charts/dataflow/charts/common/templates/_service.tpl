{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate normalized service configuration

Usage:
  # Mode 1: Specific service
  {{ include "common.service" (dict "service" "server" "global" .) }}

  # Mode 2: Global Values
  {{ include "common.service" . }}
*/}}
{{- define "common.service" -}}
{{- $context := . -}}

{{- if and (kindIs "map" .) (hasKey . "global") -}}
  {{/* Mode 1: dict with explicit global */}}
  {{- $global := .global -}}
  {{- $hasService := hasKey . "service" -}}

  {{- if $hasService -}}
    {{- $serviceType := .service -}}
    {{- $svc := index $global.Values $serviceType | default dict -}}
    {{- $defaultName := kebabcase $serviceType -}}
    {{- $name := dig "name" $defaultName $svc -}}
    {{- $merged := mergeOverwrite (dict "name" $name) $svc -}}
    {{- toYaml $merged -}}
  {{- else -}}
    {{- $svc := merge (dict) $global.Values -}}  {{/* convert chartutil.Values -> map */}}
    {{- $name := dig "name" "global" $svc -}}
    {{- $merged := mergeOverwrite (dict "name" $name) $svc -}}
    {{- toYaml $merged -}}
  {{- end -}}
{{- else -}}
  {{/* Mode 2: called directly with . */}}
  {{- $svc := merge (dict) .Values -}}            {{/* convert chartutil.Values -> map */}}
  {{- $name := dig "name" .Release.Name $svc -}}
  {{- $merged := mergeOverwrite (dict "name" $name) $svc -}}
  {{- toYaml $merged -}}
{{- end -}}
{{- end -}}