{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate PostgreSQL Connection Configuration

Usage:
{{ include "csghub.postgresql.config" (dict "service" .Values.servicename "global" .) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- global: Global configuration values (e.g., .)

Returns: YAML configuration object with PostgreSQL connection parameters
*/}}
{{- define "csghub.postgresql.config" -}}
  {{- $service := .service -}}
  {{- $global := .global -}}

  {{- /* Configuration priority: internal PostgreSQL (if enabled) > service-level external > global external */ -}}

  {{- /* Default configuration for internal PostgreSQL */ -}}
  {{- $postgresqlName := include "common.names.custom" (list $global "postgresql") -}}
  {{- $postgresqlConfig := dict
    "host" $postgresqlName
    "port" (include "csghub.svc.port" "postgresql")
    "user" ($service.postgresql.user | default "postgres")
    "password" (include "common.randomPassword" ($service.postgresql.user | default "postgres"))
    "database" ($service.postgresql.database | default "postgres")
    "timezone" "Etc/UTC"
    "sslmode" "prefer"
  -}}

  {{- /* If internal PostgreSQL is enabled and secret exists, use existing password */ -}}
  {{- if $global.Values.global.postgresql.enabled -}}
    {{- $secret := (lookup "v1" "Secret" $global.Release.Namespace $postgresqlName) -}}
    {{- if and $secret (index $secret.data $postgresqlConfig.user) -}}
      {{- $_ := set $postgresqlConfig "password" (index $secret.data $postgresqlConfig.user | b64dec) -}}
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
  {{- $config := include "csghub.postgresql.config" (dict "service" $service "global" $global) | fromYaml -}}
  {{- printf "host=%s port=%s user=%s password=%s dbname=%s sslmode=%s" $config.host $config.port $config.user $config.password $config.database $config.sslmode -}}
{{- end -}}