{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Wait for Redis to be ready before starting the service
Usage: {{ include "wait-for-redis" (dict "ctx" . "service" $service) }}
*/}}
{{- define "wait-for-redis" -}}
{{- $ctx := .ctx -}}
{{- $service := .service -}}
{{- $redisConfig := include "common.redis.config" (dict "ctx" $ctx "service" $service) | fromYaml -}}
- name: wait-for-redis
  image: {{ include "common.image.fixed" (dict "ctx" $ctx "service" "" "image" "opencsghq/redis-cli:latest") }}
  imagePullPolicy: {{ or $ctx.Values.global.image.pullPolicy "IfNotPresent" | quote }}
  command:
    - /bin/sh
    - -c
    - |
      echo "Waiting for Redis to be ready..."
      {{- if $redisConfig.password }}
      until redis-cli -h {{ $redisConfig.host }} -p {{ $redisConfig.port }} -a {{ $redisConfig.password }} ping | grep -q 'PONG'; do
      {{- else }}
      until redis-cli -h {{ $redisConfig.host }} -p {{ $redisConfig.port }} ping | grep -q 'PONG'; do
      {{- end }}
        echo "Redis is unavailable - sleeping"
        sleep 5
      done
      echo "Redis is ready!"
{{- end -}}

{{/*
Wait for PostgreSQL to be ready before starting the service
Usage: {{ include "wait-for-postgresql" (dict "ctx" . "service" $service) }}
*/}}
{{- define "wait-for-postgresql" -}}
{{- $ctx := .ctx -}}
{{- $service := .service -}}
{{- $pgConfig := include "common.postgresql.config" (dict "ctx" $ctx "service" $service) | fromYaml -}}
- name: wait-for-postgresql
  image: {{ include "common.image.fixed" (dict "ctx" $ctx "service" "" "image" "opencsghq/psql:latest") }}
  imagePullPolicy: {{ or $ctx.Values.global.image.pullPolicy "IfNotPresent" | quote }}
  command:
    - /bin/sh
    - -c
    - |
      echo "Waiting for PostgreSQL to be ready..."
      until pg_isready -h {{ $pgConfig.host }} -p {{ $pgConfig.port }} -U {{ $pgConfig.user }} -d {{ $pgConfig.database }}; do
        echo "PostgreSQL is unavailable - sleeping"
        sleep 5
      done
      echo "PostgreSQL is ready!"
{{- end -}}

