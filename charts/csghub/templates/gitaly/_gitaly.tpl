{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
# Gitaly Readiness Check Template
# Creates a Kubernetes init container that waits for Gitaly service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-gitaly" (dict "service" $service "global" .) }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-gitaly" }}
{{- $service := .service -}}
{{- $global := .global -}}
{{- $gitalyConfig := include "common.gitaly.config" (dict "service" $service "global" $global) | fromYaml -}}
{{- $serverImage := include "csghub.service.image" (dict "service" $service "context" $global) | fromYaml }}
- name: wait-for-gitaly
  image: {{ include "common.image.fixed" (dict "ctx" $global "service" "" "image" "busybox:latest") }}
  imagePullPolicy: {{ or $global.Values.image.pullPolicy $global.Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until nc -z {{ $gitalyConfig.host }} {{ $gitalyConfig.port }};
      do
        echo 'Waiting for Gitaly to be ready...';
        sleep 5;
      done
      echo 'Gitaly is ready!'
{{- end }}