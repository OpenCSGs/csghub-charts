{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
# Redis Readiness Check Template
# Creates a Kubernetes init container that waits for Redis service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-redis" (dict "service" $service "global" .) }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image template (image reference helper)
*/}}
{{- define "wait-for-redis" }}
{{- $service := .service -}}
{{- $global := .global -}}
{{- $redisSvc := include "common.service" (dict "service" "redis" "global" $global) | fromYaml -}}
{{- $redisConfig := include "common.redis.config" (dict "service" $service "global" $global) | fromYaml -}}
- name: wait-for-redis
  image: {{ include "common.image" (list $global $redisSvc.image) }}
  imagePullPolicy: {{ or $redisSvc.image.pullPolicy $global.Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      {{- if or (and $global.Values.global.redis.enabled $redisSvc.requirePass) (and (not $global.Values.global.redis.enabled) $redisConfig.password) }}
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
