{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Redis Connection Configuration
*/}}
{{- define "csghub.redis.config" -}}
{{- $service := .service -}}
{{- $global := .global -}}

{{- /* Configuration priority: internal Redis (if enabled) > service-level external > global external */ -}}

{{- /* Default configuration for internal Redis */ -}}
{{- $redisName := include "common.names.custom" (list $global "redis") -}}
{{- $redisConfig := dict
  "host" $redisName
  "port" (include "csghub.svc.port" "redis")
  "user" "default"
  "password" (include "common.randomPassword" "redis")
-}}

{{- /* If internal Redis is enabled and secret exists, use existing password */ -}}
{{- if $global.Values.global.redis.enabled -}}
  {{- $secret := (lookup "v1" "Secret" $global.Release.Namespace $redisName) -}}
  {{- if and $secret $secret.data.REDIS_PASSWD -}}
    {{- $_ := set $redisConfig "password" ($secret.data.REDIS_PASSWD | b64dec) -}}
  {{- end -}}
{{- end -}}

{{- /* Override with external Redis configuration if internal is disabled */ -}}
{{- if not $global.Values.global.redis.enabled -}}
  {{- /* Global external Redis configuration */ -}}
  {{- with $global.Values.global.redis.external -}}
    {{- $redisConfig = merge $redisConfig (dict
      "host" (.host | default $redisConfig.host)
      "port" (.port | default $redisConfig.port)
      "user" (.user | default $redisConfig.user)
      "password" (.password | default $redisConfig.password)
    ) -}}
  {{- end -}}

  {{- /* Service-level external Redis configuration (higher priority) */ -}}
  {{- with $service.redis -}}
    {{- $redisConfig = merge $redisConfig (dict
      "host" (.host | default $redisConfig.host)
      "port" (.port | default $redisConfig.port)
      "user" (.user | default $redisConfig.user)
      "password" (.password | default $redisConfig.password)
    ) -}}
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