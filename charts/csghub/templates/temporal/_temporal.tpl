{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

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
{{- $service := include "common.service" (dict "ctx" . "service" "temporal") | fromYaml }}
{{- $serviceName := include "common.names.custom" (list . $service.name) -}}
- name: wait-for-temporal
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "" "image" "busybox:latest") }}
  imagePullPolicy: {{ or .Values.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until nc -z {{ $serviceName }} {{ $service.service.port }};
      do
        echo 'Waiting for Temporal to be ready...';
        sleep 5;
      done;
      echo 'Temporal is ready!'
{{- end }}