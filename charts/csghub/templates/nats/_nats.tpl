{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
# Nats Readiness Check Template
# Creates a Kubernetes init container that waits for Nats service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-nats" . }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-nats" }}
{{- $service := include "common.service" (dict "service" "nats" "global" .) | fromYaml }}
{{- $serviceName := include "common.names.custom" (list . $service.name) -}}
- name: wait-for-nats
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "" "image" "busybox:latest") }}
  imagePullPolicy: {{ or .Values.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until wget --spider --timeout=5 --tries=1 "{{ printf "http://%s:8222" $serviceName }}/healthz" 2>/dev/null;
      do
        echo 'Waiting for Nats to be ready...';
        sleep 5;
      done;
      echo 'Nats is ready!'
{{- end }}