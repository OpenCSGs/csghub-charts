{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Common domain helper for Runner.

Usage:
  {{ include "common.domain.runner" . }}

Returns:
  <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.runner" }}
  {{- $service := include "common.service" . | fromYaml }}
  {{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
Common endpoint helper for Runner.

Usage:
  {{ include "common.endpoint.runner" . }}

Returns:
  Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.runner" }}
  {{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.runner" .)) -}}
{{- end }}

{{/*
Kaniko build arguments for runner.

Usage:
  {{ include "runner.kaniko.args" (dict "ctx" . "service" $servicename) }}

Returns:
  A single-line, comma-separated string of Kaniko build arguments.
*/}}
{{- define "runner.kaniko.args" }}
  {{- $ctx := .ctx }}
  {{- $service := .service }}
  {{- $isBuiltIn := $ctx.Values.global.chartContext.isBuiltIn }}

  {{- $registry := $service.registry }}
  {{- if $isBuiltIn }}
    {{- $registry = include "common.registry.config" (dict "ctx" $ctx "service" $service) | fromYaml }}
  {{- end }}

  {{- $kanikoCache := printf "--cache-repo=%s/%s" $registry.registry $registry.repository }}
  {{- $args := list "--compressed-caching=true" "--single-snapshot" "--log-format=text" }}
  {{- $args = concat $args (list "--cache=true" "--cache-ttl=24h" $kanikoCache) }}

  {{- if $service.pipIndexUrl }}
    {{- $args = concat $args (list (printf "--build-arg=PyPI=%s" $service.pipIndexUrl)) }}
  {{- end }}

  {{- $csghubEndpoint := $service.externalUrl }}
  {{- if $isBuiltIn }}
    {{- $csghubEndpoint = include "common.endpoint.csghub" $ctx }}
  {{- end }}
  {{- $hfEndpoint := printf "--build-arg=HF_ENDPOINT=%s/hf" $csghubEndpoint }}
  {{- $args = concat $args (list $hfEndpoint) }}

  {{- $insecure := $service.registry.insecure }}
  {{- if $isBuiltIn }}
    {{- $insecure = or $ctx.Values.global.registry.enabled (dig "registry" "external" "insecure" "true" $ctx.Values.global) }}
  {{- end }}

  {{- if $insecure }}
    {{- $args = concat $args (list
      "--skip-tls-verify"
      "--skip-tls-verify-pull"
      "--insecure"
      "--insecure-pull"
    ) }}
  {{- end }}

  {{- range $service.extraBuildArgs }}
    {{- $args = concat $args (list .) }}
  {{- end }}

  {{- join "," $args | nospace -}}
{{- end }}

{{/*
Loki readiness check.

Creates a Kubernetes init container that waits for Loki service to become ready
before proceeding with pod startup.

Usage:
  {{ include "wait-for-loki" . }}
*/}}
{{- define "wait-for-loki" }}
  {{- $service := include "common.service" . | fromYaml }}
  {{- $lokiAddress := $service.logcollector.loki.address }}
  {{- if .Values.global.chartContext.isBuiltIn }}
    {{- $lokiSvc := include "common.service" (dict "ctx" . "service" "loki") | fromYaml }}
    {{- $lokiSvcName := include "common.names.custom" (list . $lokiSvc.name) }}
    {{- $lokiSvcPort := dig "service" "port" 3100 $lokiSvc }}
    {{- $lokiAddress = printf "http://%s:%v" $lokiSvcName $lokiSvcPort }}
  {{- end }}
  - name: wait-for-loki
    image: {{ include "common.image.fixed" (dict "ctx" . "service" "" "image" "busybox:latest") }}
    imagePullPolicy: {{ or .Values.image.pullPolicy .Values.global.image.pullPolicy | quote }}
    command:
      - /bin/sh
      - -c
      - |
        until wget --spider --timeout=5 --tries=1 "{{ printf "%s/ready" (required "Loki address is required" $lokiAddress) }}";
        do
          echo 'Waiting for Loki to be ready...';
          sleep 5;
        done
        echo 'Loki is ready!'
{{- end }}