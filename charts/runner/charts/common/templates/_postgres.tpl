{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate PostgreSQL Connection Configuration

Usage:
{{ include "common.postgresql.config" (dict "service" .Values.servicename "global" .) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- global: Global configuration values (e.g., .)

Returns: YAML configuration object with PostgreSQL connection parameters
*/}}
{{- define "common.postgresql.config" -}}
  {{- $service := .service -}}
  {{- $global := .global -}}

  {{- /* Configuration priority: internal PostgreSQL (if enabled) > service-level external > global external */ -}}

  {{- /* Default configuration for internal PostgreSQL */ -}}
  {{- $postgresSvc := include "common.service" (dict "service" "postgresql" "global" $global) | fromYaml }}
  {{- $postgresqlName := include "common.names.custom" (list $global $postgresSvc.name) -}}
  {{- $serviceName := include "common.names.custom" (list $global $service.name) -}}
  {{- $postgresqlConfig := dict
    "host" $postgresqlName
    "port" ($postgresSvc.service.port)
    "user" "csghub"
    "password" (include "common.randomPassword" "csghub")
    "database" ($service.postgresql.database | default ( $serviceName | replace "-" "_"))
    "timezone" "Etc/UTC"
    "sslmode" "disable"
  -}}

  {{- /* If internal PostgreSQL is enabled and secret exists, use existing password */ -}}
  {{- if $global.Values.global.postgresql.enabled -}}
    {{- $secret := (lookup "v1" "Secret" $global.Release.Namespace $postgresqlName) -}}
    {{- if and $secret (index $secret.data "POSTGRES_PASSWORD") -}}
      {{- $_ := set $postgresqlConfig "password" (index $secret.data "POSTGRES_PASSWORD" | b64dec) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Override with external PostgreSQL configuration if internal is disabled */ -}}
  {{- if not $global.Values.global.postgresql.enabled -}}
    {{- /* Global external PostgreSQL configuration */ -}}
    {{- with $global.Values.global.postgresql.external -}}
      {{- $postgresqlConfig = merge (dict
        "host" (.host | default $postgresqlConfig.host)
        "port" (.port | default $postgresqlConfig.port)
        "user" (.user | default $postgresqlConfig.user)
        "password" (.password | default $postgresqlConfig.password)
        "database" (.database | default $postgresqlConfig.database)
        "timezone" (.timezone | default $postgresqlConfig.timezone)
        "sslmode" (.sslmode | default $postgresqlConfig.sslmode)
      ) $postgresqlConfig -}}
    {{- end -}}

    {{- /* Service-level external PostgreSQL configuration (higher priority) */ -}}
    {{- with $service.postgresql -}}
      {{- $postgresqlConfig = merge (dict
        "host" (.host | default $postgresqlConfig.host)
        "port" (.port | default $postgresqlConfig.port)
        "user" (.user | default $postgresqlConfig.user)
        "password" (.password | default $postgresqlConfig.password)
        "database" (.database | default $postgresqlConfig.database)
        "timezone" (.timezone | default $postgresqlConfig.timezone)
        "sslmode" (.sslmode | default $postgresqlConfig.sslmode)
      ) $postgresqlConfig -}}
    {{- end -}}
  {{- end -}}

  {{- /* Validate required configurations */ -}}
  {{- if not $postgresqlConfig.password -}}
    {{- fail "PostgreSQL password must be set" -}}
  {{- end -}}

  {{- if not $postgresqlConfig.host -}}
    {{- fail "PostgreSQL host must be set" -}}
  {{- end -}}

  {{- if not $postgresqlConfig.database -}}
    {{- fail "PostgreSQL database name must be set" -}}
  {{- end -}}

  {{- $postgresqlConfig | toYaml -}}
{{- end -}}

{{/*
Generate PostgreSQL Database DSN (Data Source Name)

Usage:
{{ include "csghub.postgresql.dsn" (dict "service" .Values.servicename "global" .) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- global: Global configuration values (e.g., .)

Returns: PostgreSQL connection string in DSN format
*/}}
{{- define "csghub.postgresql.dsn" -}}
  {{- $service := .service -}}
  {{- $global := .global -}}
  {{- $config := include "common.postgresql.config" (dict "service" $service "global" $global) | fromYaml -}}
  {{- printf "postgresql://%s:%s@%s:%s/%s?sslmode=%s" $config.user $config.password $config.host ($config.port | toString) $config.database $config.sslmode -}}
{{- end -}}