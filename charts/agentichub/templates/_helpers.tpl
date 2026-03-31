{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Wait for Redis to be ready before starting the service
Usage: {{ include "wait-for-redis" (dict "service" $service "ctx" .) }}
*/}}
{{- define "wait-for-redis" -}}
{{- $service := .service -}}
{{- $ctx := .ctx -}}
{{- $redisConfig := include "common.redis.config" (dict "service" $service "ctx" $ctx) | fromYaml -}}
{{- if $redisConfig.password -}}
- name: wait-for-redis
  image: {{ include "common.image" (list $ctx (dict "registry" "docker.io" "repository" "bitnami/redis-cli" "tag" "latest")) }}
  command:
    - /bin/sh
    - -c
    - |
      echo "Waiting for Redis to be ready..."
      until redis-cli -h {{ $redisConfig.host }} -p {{ $redisConfig.port }} -a {{ $redisConfig.password }} ping | grep -q 'PONG'; do
        echo "Redis is unavailable - sleeping"
        sleep 5
      done
      echo "Redis is ready!"
{{- else -}}
- name: wait-for-redis
  image: {{ include "common.image" (list $ctx (dict "registry" "docker.io" "repository" "bitnami/redis-cli" "tag" "latest")) }}
  command:
    - /bin/sh
    - -c
    - |
      echo "Waiting for Redis to be ready..."
      until redis-cli -h {{ $redisConfig.host }} -p {{ $redisConfig.port }} ping | grep -q 'PONG'; do
        echo "Redis is unavailable - sleeping"
        sleep 5
      done
      echo "Redis is ready!"
{{- end -}}
{{- end -}}

{{/*
Wait for PostgreSQL to be ready before starting the service
Usage: {{ include "wait-for-postgresql" (dict "service" $service "ctx" .) }}
*/}}
{{- define "wait-for-postgresql" -}}
{{- $service := .service -}}
{{- $ctx := .ctx -}}
{{- $pgConfig := include "common.postgresql.config" (dict "service" $service "ctx" $ctx) | fromYaml -}}
- name: wait-for-postgresql
  image: {{ include "common.image" (list $ctx (dict "registry" "docker.io" "repository" "bitnami/postgresql" "tag" "latest")) }}
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
