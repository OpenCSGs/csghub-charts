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

{{- /*
# Temporal Schema Setup
# Creates a Kubernetes init container that creates the Temporal and visibility
# databases and brings their schemas up to date via temporal-sql-tool from the
# admin-tools image, pinned to the Temporal server image tag.
# Safe to re-run: create-database tolerates an existing database and
# setup-schema/update-schema are no-ops once the schema is current.
#
# Usage: {{ include "temporal-schema-setup" (dict "ctx" . "service" $service) }}
#
# Dependencies:
#   - common.postgresql.config template (connection details)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "temporal-schema-setup" }}
{{- $ctx := .ctx }}
{{- $service := .service }}
{{- $pgConfig := include "common.postgresql.config" (dict "ctx" $ctx "service" $service) | fromYaml }}
- name: temporal-schema-setup
  image: {{ include "common.image.fixed" (dict "ctx" $ctx "service" "temporal" "image" (printf "temporalio/admin-tools:%s" $service.image.tag)) }}
  imagePullPolicy: {{ or $service.image.pullPolicy $ctx.Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      set -e
      setup_store() {
        temporal-sql-tool --db "$1" create-database || true
        temporal-sql-tool --db "$1" setup-schema -v 0.0
        temporal-sql-tool --db "$1" update-schema --schema-dir "/etc/temporal/schema/postgresql/v12/$2/versioned"
      }
      setup_store "{{ $pgConfig.database }}" temporal
      setup_store "{{ $pgConfig.database }}_visibility" visibility
  env:
    - name: SQL_PLUGIN
      value: "postgres12"
    - name: SQL_HOST
      value: {{ $pgConfig.host | quote }}
    - name: SQL_PORT
      value: {{ $pgConfig.port | quote }}
    - name: SQL_USER
      value: {{ $pgConfig.user | quote }}
    - name: SQL_PASSWORD
      value: {{ $pgConfig.password | quote }}
    {{- if ne $pgConfig.sslmode "disable" }}
    - name: SQL_TLS
      value: "true"
    {{- if regexMatch ".*.rds.amazonaws.com$" $pgConfig.host }}
    - name: SQL_TLS_CA_FILE
      value: "/etc/certs/aws-ca-bundle.pem"
    - name: SQL_TLS_DISABLE_HOST_VERIFICATION
      value: "true"
    {{- end }}
    {{- end }}
  {{- if ne $pgConfig.sslmode "disable" }}
  volumeMounts:
    - name: certs
      mountPath: "/etc/certs"
  {{- end }}
{{- end }}