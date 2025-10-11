{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Kaniko build arguments for runner.

Usage:
  {{ include "runner.kaniko.args" (dict "service" $servicename "global" .) }}

Returns:
  A single-line, comma-separated string of Kaniko build arguments.
*/}}
{{- define "runner.kaniko.args" -}}
{{- $service := .service -}}
{{- $global := .global -}}

{{- $args := list "--compressed-caching=false" "--single-snapshot" "--log-format=text" -}}

{{- if $service.pipIndexUrl }}
  {{- $args = concat $args (list (printf "--build-arg=PyPI=%s" $service.pipIndexUrl)) -}}
{{- end }}

{{- $csghubEndpoint := include "common.endpoint.csghub" $global }}
{{- if not $service.chartContext.isBuiltIn }}
{{- $csghubEndpoint = $service.externalUrl }}
{{- end }}
{{- $hfEndpoint := printf "--build-arg=HF_ENDPOINT=%s/hf" $csghubEndpoint -}}
{{- $args = concat $args (list $hfEndpoint) -}}

{{- $insecure := false }}
{{- if $service.chartContext.isBuiltIn }}
  {{- $insecure = or $global.Values.global.registry.enabled $global.Values.global.registry.external.insecure }}
{{- else }}
  {{- $insecure = $service.registry.insecure }}
{{- end }}

{{- if $insecure }}
  {{- $args = concat $args (list
    "--skip-tls-verify"
    "--skip-tls-verify-pull"
    "--insecure"
    "--insecure-pull"
  ) -}}
{{- end }}

{{- range $service.extraBuildArgs }}
  {{- $args = concat $args (list .) -}}
{{- end }}

{{- join "," $args | nospace -}}
{{- end }}