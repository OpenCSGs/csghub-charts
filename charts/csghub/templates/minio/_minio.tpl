{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# MinIO Domain Helper
# Generates the full domain name for MinIO service based on configuration
# Usage: {{ include "common.domain.minio" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.minio" -}}
{{- $service := include "common.service" (dict "service" "minio" "global" .) | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# MinIO External Endpoint Helper
# Generates the complete external access endpoint for MinIO service
# Usage: {{ include "external.endpoint.minio" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.minio" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.minio" .)) -}}
{{- end }}

{{- /*
# MinIO Readiness Check Template
# Creates a Kubernetes init container that waits for MinIO service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-minio" . }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-minio" }}
{{- $service := include "common.service" (dict "service" "minio" "global" .) | fromYaml }}
{{- $serviceName := include "common.names.custom" (list . $service.name) -}}
- name: wait-for-minio
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "minio" "image" "busybox:latest") }}
  imagePullPolicy: {{ or .Values.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until wget --spider --timeout=5 --tries=1 "{{ printf "http://%s:%s" $serviceName ($service.service.port | toString) }}/minio/health/live";
      do
        echo 'Waiting for MinIO to be ready...';
        sleep 5;
      done
      echo 'MinIO is ready!'
{{- end }}