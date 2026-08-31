{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Casdoor readiness check.

Creates a Kubernetes init container that waits for Casdoor service to become
ready by probing the /api/health endpoint.

Usage: {{ include "wait-for-casdoor" . }}
*/}}
{{- define "wait-for-casdoor" }}
{{- $service := include "common.service" (dict "ctx" . "service" "casdoor") | fromYaml }}
{{- $serviceName := include "common.names.custom" (list . $service.name) -}}
- name: wait-for-casdoor
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "" "image" "busybox:latest") }}
  imagePullPolicy: {{ or .Values.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until wget --spider --timeout=5 --tries=1 "{{ printf "http://%s:%s" $serviceName ($service.service.port | toString) }}/api/health";
      do
        echo 'Waiting for Casdoor to be ready...';
        sleep 5;
      done;
      echo 'Casdoor is ready!'
{{- end }}

{{/*
PostgreSQL readiness check.

Creates a Kubernetes init container that waits for PostgreSQL service to become
ready by running `psql -c 'SELECT 1'` via the csghub.postgresql.dsn helper.

Usage: {{ include "wait-for-postgresql" (dict "ctx" . "service" $service) }}
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
      until psql {{ include "csghub.postgresql.dsn" (dict "ctx" $ctx "service" $service) | quote }} -c 'SELECT 1';
      do
        echo 'Waiting for PostgreSQL to be ready...';
        sleep 5;
      done;
      echo 'PostgreSQL is ready!'
{{- end }}

{{/*
Redis readiness check.

Creates a Kubernetes init container that waits for Redis service to become ready
by probing `redis-cli ping` until it returns PONG. When auth is configured, the
password is passed with quote escaping.

Usage: {{ include "wait-for-redis" (dict "ctx" . "service" $service) }}
*/}}
{{- define "wait-for-redis" }}
{{- $ctx := .ctx }}
{{- $service := .service }}
{{- $redisSvc := include "common.service" (dict "ctx" $ctx "service" "redis") | fromYaml }}
{{- $redisConfig := include "common.redis.config" (dict "ctx" $ctx "service" $service) | fromYaml }}
- name: wait-for-redis
  image: {{ include "common.image" (list $ctx $redisSvc.image) }}
  imagePullPolicy: {{ or $redisSvc.image.pullPolicy $ctx.Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      {{- if or (and $ctx.Values.global.redis.enabled $redisSvc.requirePass) (and (not $ctx.Values.global.redis.enabled) $redisConfig.password) }}
      until redis-cli -h {{ $redisConfig.host }} -p {{ $redisConfig.port }} -a {{ $redisConfig.password | quote }} ping | grep -q "PONG";
      {{- else }}
      until redis-cli -h {{ $redisConfig.host }} -p {{ $redisConfig.port }} ping | grep -q "PONG";
      {{- end }}
      do
        echo 'Waiting for Redis to be ready...';
        sleep 5;
      done
      echo 'Redis is ready!'
{{- end }}

{{/*
Web (CSGShip) readiness check.

Creates a Kubernetes init container that waits for the Web service port to
become open.

Usage: {{ include "wait-for-web" . }}
*/}}
{{- define "wait-for-web" }}
{{- $service := include "common.service" (dict "ctx" . "service" "web") | fromYaml }}
{{- $serviceName := include "common.names.custom" (list . $service.name) }}
{{- $serverPort := dig "service" "port" 8000 $service | toString }}
- name: wait-for-web
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "web" "image" "busybox:latest") }}
  imagePullPolicy: {{ or $service.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until nc -z {{ $serviceName }} {{ $serverPort }};
      do
        echo 'Waiting for CSGShip Web port to be open...';
        sleep 5;
      done
      echo 'CSGShip Web port is open!'
{{- end }}

{{/*
CSGHub Server readiness check.

Creates a Kubernetes init container that waits for the Server service to become
ready by probing the /healthz endpoint.

Usage: {{ include "wait-for-server" . }}
*/}}
{{- define "wait-for-server" }}
{{- $service := include "common.service" (dict "ctx" . "service" "server") | fromYaml }}
{{- $serviceName := include "common.names.custom" (list . $service.name) }}
{{- $serverPort := dig "service" "port" 8080 $service | toString }}
- name: wait-for-server
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "" "image" "busybox:latest") }}
  imagePullPolicy: {{ or .Values.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until wget --spider --timeout=5 --tries=1 "{{ printf "http://%s:%s" $serviceName $serverPort }}/healthz";
      do
        echo 'Waiting for CSGHub Server to be ready...';
        sleep 5;
      done
      echo 'CSGHub Server is ready!'
{{- end }}
