{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# csghub Domain Helper
# Generates the full domain name for csghub service based on configuration
# Usage: {{ include "common.domain.csghub" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.csghub" -}}
{{- $sub := .Release.Name }}
{{- if .Values.global.ingress.useTop }}
{{- $sub = "" }}
{{- end }}
{{- include "common.domain" (dict "ctx" . "sub" $sub) -}}
{{- end }}

{{/*
# csghub Public Domain Helper
# Generates the full domain name for csghub service based on configuration
# Usage: {{ include "common.domain.public" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.public" -}}
{{- $sub := "public" }}
{{- if .Values.global.ingress.useTop }}
{{- $sub = "" }}
{{- end }}
{{- include "common.domain" (dict "ctx" . "sub" $sub) -}}
{{- end }}

{{/*
# csghub External Endpoint Helper
# Generates the complete external access endpoint for csghub service
# Usage: {{ include "external.endpoint.csghub" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.csghub" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.csghub" .)) -}}
{{- end }}

{{/*
Generate global unique HUB_SERVER_API_TOKEN

Usage:
{{ include "csghub.api.token" . }}

Parameters:
- global: Global context (e.g., .)

Returns: Unique API token string that changes on every installation
*/}}
{{- define "csghub.api.token" -}}
  {{- $global := . -}}

  {{- /* Generate random seed for uniqueness across installations */ -}}
  {{- $seed := now | date "200601021504" -}}

  {{- /* Create unique hashes combining release info with random seed */ -}}
  {{- $namespaceHash := (printf "%s-%s" $global.Release.Namespace $seed | sha256sum) -}}
  {{- $nameHash := (printf "%s-%s" $global.Release.Name $seed | sha256sum) -}}

  {{- /* Combine hashes to form final token */ -}}
  {{- printf "%s%s" $namespaceHash $nameHash -}}
{{- end -}}

{{/*
Resolve service image with proper tag
Usage:
  {{ include "csghub.service.image" (dict "service" .Values.rproxy "context" .) }}
*/}}
{{- define "csghub.service.image" -}}
{{- $service := .service -}}
{{- $context := .context -}}

{{- $baseImage := deepCopy (default (dict) $context.Values.image) -}}
{{- $serviceImage := deepCopy (default (dict) $service.image) -}}

{{- $tag := or (dig "image" "tag" "" $service) $baseImage.tag $context.Values.global.image.tag -}}
{{- $finalTag := include "common.image.tag" (dict "tag" $tag "context" $context) -}}

{{- $mergedImage := mergeOverwrite $baseImage $serviceImage -}}
{{- $_ := set $mergedImage "tag" $finalTag -}}

{{- $mergedImage | toYaml -}}
{{- end -}}

{{- /*
# CSGHub Server Readiness Check Template
# Creates a Kubernetes init container that waits for Server service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-server" . }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-server" }}
{{- $service := include "common.service" (dict "service" "server" "global" .) | fromYaml -}}
{{- $serviceName := include "common.names.custom" (list . $service.name) -}}
{{- $serverPort := dig "service" "port" "8080" $service | toString -}}
- name: wait-for-server
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "" "image" "busybox:latest") }}
  imagePullPolicy: {{ or .Values.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until wget --spider --timeout=5 --tries=1 "{{ printf "http://%s:%s" $serviceName $serverPort }}/healthz";
      do
        echo 'Waiting for CSGHub Server to be ready...';
        sleep 5;
      done
      echo 'CSGHub Server is ready!'
{{- end }}