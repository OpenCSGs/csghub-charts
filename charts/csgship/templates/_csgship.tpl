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
{{- $service := include "common.service" (dict "ctx" . "service" "web") | fromYaml }}
{{- $serviceName := include "common.names.custom" (list . $service.name) }}
{{- $serverPort := dig "service" "port" 8000 $service | toString }}
- name: wait-for-web
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "web" "image" "busybox:latest") }}
  imagePullPolicy: {{ or $service.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until nc -z {{ $serviceName }} {{ $serverPort }};
      do
        echo 'Waiting for CSGShip Web port to be open...';
        sleep 5;
      done
      echo 'CSGShip Web port is open!'
{{- end }}