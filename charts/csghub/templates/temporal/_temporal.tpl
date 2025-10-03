{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# Temporal Domain Helper
# Generates the full domain name for Temporal service based on configuration
# Usage: {{ include "common.domain.temporal" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.temporal" -}}
{{- $service := include "common.service" (dict "service" "temporal" "global" .) | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# Temporal External Endpoint Helper
# Generates the complete external access endpoint for Temporal service
# Usage: {{ include "external.endpoint.temporal" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.temporal" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.temporal" .)) -}}
{{- end }}

{{- /*
# Temporal Readiness Check Template
# Creates a Kubernetes init container that waits for Temporal service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-temporal" . }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-temporal" }}
{{- $service := include "common.service" (dict "service" "temporal" "global" .) | fromYaml }}
{{- $serviceName := include "common.names.custom" (list . $service.name) -}}
- name: wait-for-temporal
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "temporal" "image" "busybox:latest") }}
  imagePullPolicy: {{ .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until nc -z {{ $serviceName }} {{ $service.service.port }} 2>/dev/null;
      do
        echo 'Waiting for Temporal to be ready...';
        sleep 5;
      done;
      echo 'Temporal is ready!'
{{- end }}