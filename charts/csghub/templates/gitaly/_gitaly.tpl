{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
# Gitaly Readiness Check Template
# Creates a Kubernetes init container that waits for Gitaly service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-gitaly" (dict "ctx" . "service" $service) }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-gitaly" }}
{{- $ctx := .ctx }}
{{- $service := .service }}
{{- $gitalyConfig := include "common.gitaly.config" (dict "ctx" $ctx "service" $service) | fromYaml }}
{{- $serverImage := include "csghub.service.image" (dict "ctx" $ctx "service" $service) | fromYaml }}
- name: wait-for-gitaly
  image: {{ include "common.image.fixed" (dict "ctx" $ctx "service" "" "image" "busybox:latest") }}
  imagePullPolicy: {{ or $ctx.Values.image.pullPolicy $ctx.Values.global.image.pullPolicy | quote }}
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