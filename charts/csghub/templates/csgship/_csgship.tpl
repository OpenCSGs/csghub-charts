{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# CSGShip Domain Helper
# Generates the full domain name for CSGShip service based on configuration
# Usage: {{ include "common.domain.web" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.web" -}}
{{- $service := include "common.service" (dict "service" "web" "global" .) | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# CSGShip External Endpoint Helper
# Generates the complete external access endpoint for CSGShip service
# Usage: {{ include "common.endpoint.web" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.web" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.web" .)) -}}
{{- end }}

{{/*
# CSGShip API Domain Helper
# Generates the full domain name for CSGShip API service based on configuration
# Usage: {{ include "common.domain.webAPI" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.webAPI" -}}
{{- $service := include "common.service" (dict "service" "web" "global" .) | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" (printf "%s-api" $service.name)) -}}
{{- end }}

{{/*
# CSGShip API External Endpoint Helper
# Generates the complete external access endpoint for CSGShip API service
# Usage: {{ include "common.endpoint.webAPI" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.webAPI" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.webAPI" .)) -}}
{{- end }}

{{/*
Resolve service image with proper tag
Usage:
  {{ include "csgship.service.image" (dict "service" .Values.rproxy "context" .) }}
*/}}
{{- define "csgship.service.image" -}}
{{- $service := .service -}}
{{- $context := .context -}}

{{- $baseImage := deepCopy (default (dict) $context.Values.image) -}}
{{- $serviceImage := deepCopy (default (dict) $service.image) -}}

{{- $mergedImage := mergeOverwrite $baseImage $serviceImage -}}

{{- $mergedImage | toYaml -}}
{{- end -}}

{{- /*
# CSGShip Web Readiness Check Template
# Creates a Kubernetes init container that waits for Web service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-web" . }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-web" }}
{{- $service := include "common.service" (dict "service" "web" "global" .) | fromYaml -}}
{{- $serviceName := include "common.names.custom" (list . $service.name) -}}
{{- $serverPort := dig "service" "port" 8000 $service | toString -}}
- name: wait-for-web
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "web" "image" "busybox:latest") }}
  imagePullPolicy: {{ or $service.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until wget --spider --timeout=5 --tries=1 "{{ printf "http://%s:%s" $serviceName $serverPort }}";
      do
        echo 'Waiting for CSGShip Web to be ready...';
        sleep 5;
      done
      echo 'CSGShip Web is ready!'
{{- end }}