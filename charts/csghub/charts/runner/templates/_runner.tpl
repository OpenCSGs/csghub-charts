{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# Runner Domain Helper
# Generates the full domain name for Runner service based on configuration
# Usage: {{ include "common.domain.runner" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.runner" -}}
{{- $service := include "common.service" . | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# Runner External Endpoint Helper
# Generates the complete external access endpoint for Runner service
# Usage: {{ include "external.endpoint.runner" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.runner" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.runner" .)) -}}
{{- end }}

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

{{- $args := list "--compressed-caching=true" "--single-snapshot" "--log-format=text" -}}
{{- $args = concat $args (list "--cache=true" "--cache-ttl=24h" "--cache-repo=registry.cn-beijing.aliyuncs.com/opencsg_space/kaniko-cache") }}

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

{{- /*
# Loki Readiness Check Template
# Creates a Kubernetes init container that waits for Server service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-loki" . }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-loki" }}
{{- $service := include "common.service" . | fromYaml -}}
- name: wait-for-loki
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "" "image" "busybox:latest") }}
  imagePullPolicy: {{ or .Values.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until wget --spider --timeout=5 --tries=1 "{{ printf "%s/ready" (required "Loki address is required" $service.logcollector.loki.address) }}";
      do
        echo 'Waiting for Loki to be ready...';
        sleep 5;
      done
      echo 'Loki is ready!'
{{- end }}