{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
# PostgreSQL Readiness Check Template
# Creates a Kubernetes init container that waits for PostgreSQL service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-postgresql" (dict "ctx" . "service" $service) }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-postgresql" }}
{{- $ctx := .ctx }}
{{- $service := .service }}
- name: wait-for-postgresql
  image: {{ include "common.image.fixed" (dict "ctx" $ctx "service" "" "image" "opencsghq/psql:latest") }}
  imagePullPolicy: {{ or $service.image.pullPolicy $ctx.Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until psql {{ include "csghub.postgresql.dsn" (dict "service" $service "ctx" $ctx) | quote }} -c 'SELECT 1';
      do
        echo 'Waiting for PostgreSQL to be ready...';
        sleep 5;
      done;
      echo 'PostgreSQL is ready!'
{{- end }}