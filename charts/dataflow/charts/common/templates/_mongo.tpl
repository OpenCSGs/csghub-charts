{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Mongo Connection Configuration

Usage:
{{ include "common.mongo.config" (dict "ctx" . "service" .Values.servicename) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- ctx: Global configuration values (e.g., .)

Returns: YAML configuration object with MongoDB connection parameters
*/}}
{{- define "common.mongo.config" }}
  {{- $service := .service }}
  {{- $ctx := .ctx }}

  {{- /* Configuration priority: internal Mongo (if enabled) > service-level external > global external */}}

  {{- /* Default configuration for internal Mongo */}}
  {{- $mongoSvc := include "common.service" (dict "ctx" $ctx "service" "mongo") | fromYaml }}
  {{- $mongoName := include "common.names.custom" (list $ctx $mongoSvc.name) }}
  {{- $mongoUser := dig "auth" "user" "root" $mongoSvc}}
  {{- $mongoPassword := dig "auth" "password" (include "common.randomPassword" "root") $mongoSvc}}
  {{- $mongoConfig := dict
    "host" $mongoName
    "port" (dig "service" "port" 27017 $mongoSvc)
    "user" $mongoUser
    "password" $mongoPassword
  }}

  {{- /* If internal Mongo is enabled and secret exists, use existing credentials */}}
  {{- if $ctx.Values.global.mongo.enabled }}
    {{- $secret := (lookup "v1" "Secret" $ctx.Release.Namespace $mongoName) }}
    {{- if and $secret (index $secret.data "MONGO_INITDB_ROOT_USERNAME") }}
      {{- $_ := set $mongoConfig "user" (index $secret.data "MONGO_INITDB_ROOT_USERNAME" | b64dec) }}
    {{- end }}
    {{- if and $secret (index $secret.data "MONGO_INITDB_ROOT_PASSWORD") }}
      {{- $_ := set $mongoConfig "password" (index $secret.data "MONGO_INITDB_ROOT_PASSWORD" | b64dec) }}
    {{- end }}
  {{- end }}

  {{- /* Override with external Mongo configuration if internal is disabled */}}
  {{- if not $ctx.Values.global.mongo.enabled }}
    {{- /* Global external Mongo configuration */}}
    {{- with $ctx.Values.global.mongo.external }}
      {{- $mongoConfig = merge (dict
        "host" (.host | default $mongoConfig.host)
        "port" (.port | default $mongoConfig.port)
        "user" (.user | default $mongoConfig.user)
        "password" (.password | default $mongoConfig.password)
      ) $mongoConfig }}
    {{- end }}
  {{- end }}

  {{- /* Service-level external Mongo configuration (higher priority) */}}
  {{- with $service.mongo }}
    {{- $mongoConfig = merge (dict
      "host" (.host | default $mongoConfig.host)
      "port" (.port | default $mongoConfig.port)
      "user" (.user | default $mongoConfig.user)
      "password" (.password | default $mongoConfig.password)
    ) $mongoConfig }}
  {{- end }}

  {{- /* Validate required configurations */}}
  {{- if not $mongoConfig.password }}
    {{ fail "Mongo password must be set" }}
  {{- end }}

  {{- if not $mongoConfig.host }}
    {{ fail "Mongo host must be set" }}
  {{- end }}

  {{- $mongoConfig | toYaml -}}
{{- end }}