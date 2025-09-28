{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# Casdoor Domain Helper
# Generates the full domain name for Casdoor service based on configuration
# Usage: {{ include "common.domain.casdoor" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.casdoor" -}}
{{- $service := .Values.casdoor }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# Casdoor External Endpoint Helper
# Generates the complete external access endpoint for Casdoor service
# Usage: {{ include "external.endpoint.casdoor" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.casdoor" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.casdoor" .)) -}}
{{- end }}

{{- /*
# Casdoor Readiness Check Template
# Creates a Kubernetes init container that waits for Casdoor service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-casdoor" . }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-casdoor" }}
{{- $service := .Values.casdoor -}}
{{- $serviceName := include "common.names.custom" (list . $service.name) -}}
- name: wait-for-casdoor
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "casdoor" "image" "busybox:latest") }}
  imagePullPolicy: {{ .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until nc -z {{ $serviceName }} {{ $service.service.port }};
      do
        echo 'Waiting for Casdoor to be ready...';
        sleep 5;
      done
      echo 'Casdoor is ready!'
{{- end }}