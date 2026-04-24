{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
# Redis Readiness Check Template
# Creates a Kubernetes init container that waits for Redis service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-redis" (dict "ctx" . "service" $service) }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image template (image reference helper)
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
      until redis-cli -h {{ $redisConfig.host }} -p {{ $redisConfig.port }} -a {{ $redisConfig.password }} ping | grep -q "PONG";
      {{- else }}
      until redis-cli -h {{ $redisConfig.host }} -p {{ $redisConfig.port }} ping | grep -q "PONG";
      {{- end }}
      do
        echo 'Waiting for Redis to be ready...';
        sleep 5;
      done
      echo 'Redis is ready!'
{{- end }}
