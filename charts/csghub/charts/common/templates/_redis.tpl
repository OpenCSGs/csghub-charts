{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Redis Connection Configuration

Usage:
{{ include "common.redis.config" (dict "service" .Values.servicename "global" .) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- global: Global configuration values (e.g., .)

Returns: YAML configuration object with Redis connection parameters
*/}}
{{- define "common.redis.config" -}}
  {{- $service := .service -}}
  {{- $global := .global -}}

  {{- /* Configuration priority: internal Redis (if enabled) > service-level external > global external */ -}}

  {{- /* Default configuration for internal Redis */ -}}
  {{- $redisSvc := include "common.service" (dict "service" "redis" "global" $global) | fromYaml }}
  {{- $redisName := include "common.names.custom" (list $global $redisSvc.name) -}}
  {{- $redisConfig := dict
    "host" $redisName
    "port" (dig "service" "port" "6379" $redisSvc)
    "database" (dig "redis" "database" "0" $service)
    "user" "default"
    "password" (include "common.randomPassword" $redisSvc.name)
  -}}

  {{- /* If internal Redis is enabled and secret exists, use existing password */ -}}
  {{- if $global.Values.global.redis.enabled -}}
    {{- $secret := (lookup "v1" "Secret" $global.Release.Namespace $redisName) -}}
    {{- if and $secret (index $secret.data "REDIS_PASSWD") -}}
      {{- $_ := set $redisConfig "password" (index $secret.data "REDIS_PASSWD" | b64dec) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Override with external Redis configuration if internal is disabled */ -}}
  {{- if not $global.Values.global.redis.enabled -}}
    {{- /* Global external Redis configuration */ -}}
    {{- with $global.Values.global.redis.external -}}
      {{- $redisConfig = merge (dict
        "host" (.host | default $redisConfig.host)
        "port" (.port | default $redisConfig.port)
        "database" (.database | default $redisConfig.database)
        "user" (.user | default $redisConfig.user)
        "password" (.password | default $redisConfig.password)
      ) $redisConfig -}}
    {{- end -}}

    {{- /* Service-level external Redis configuration (higher priority) */ -}}
    {{- with $service.redis -}}
      {{- $redisConfig = merge (dict
        "host" (.host | default $redisConfig.host)
        "port" (.port | default $redisConfig.port)
        "database" (.database | default $redisConfig.database)
        "user" (.user | default $redisConfig.user)
        "password" (.password | default $redisConfig.password)
      ) $redisConfig -}}
    {{- end -}}
  {{- end -}}

  {{- /* Validate required configurations */ -}}
  {{- if not $redisConfig.password -}}
    {{- fail "Redis password must be set" -}}
  {{- end -}}

  {{- if not $redisConfig.host -}}
    {{- fail "Redis host must be set" -}}
  {{- end -}}

  {{- $redisConfig | toYaml -}}
{{- end -}}