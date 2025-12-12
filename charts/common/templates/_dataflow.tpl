{{- /*
Copyright OpenCSG, Inc.
All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Dataflow Server Configuration

Usage:
{{ include "common.dataflow.config" (dict "service" .Values.servicename "global" .) }}

Description:
Selects between internal and external Dataflow server endpoints based on `.Values.global.dataflow.enabled`.

Priority:
1. Internal Dataflow service (if enabled)
2. External Dataflow configuration (if disabled)

Parameters:
- .Values.global.dataflow.enabled : bool
    Whether to use the internal Dataflow service.
- .Values.global.dataflow.external.host : string
    External Dataflow host when internal service is disabled.
- .Values.global.dataflow.external.port : int
    External Dataflow port when internal service is disabled.
*/}}
{{- /*
Copyright OpenCSG, Inc.
All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Dataflow Server Configuration

Usage:
{{ include "common.dataflow.config" (dict "service" .Values.servicename "global" .) }}

Description:
Generates configuration for connecting to the Dataflow service.
Configuration priority:
1. Internal Dataflow service (if enabled)
2. Service-level external Dataflow config
3. Global external Dataflow config

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- global: Global configuration values (e.g., .)

Returns: YAML configuration object with Dataflow connection parameters
*/}}
{{- define "common.dataflow.config" -}}
  {{- $service := .service -}}
  {{- $global := .global -}}

  {{- /* Default configuration for internal Dataflow service */ -}}
  {{- $dataflowName := include "common.names.custom" (list $global $service.name) -}}
  {{- $dataflowConfig := dict
    "host" $dataflowName
    "port" (dig "service" "port" 8000 $service)
  -}}

  {{- /* Determine if internal Dataflow service is enabled */ -}}
  {{- $enabled := dig "dataflow" "enabled" true $global.Values.global -}}

  {{- /* If internal is disabled, override with external configuration */ -}}
  {{- if not $enabled -}}
    {{- /* Global external Dataflow configuration */ -}}
    {{- with $global.Values.global.dataflow.external -}}
      {{- $dataflowConfig = merge (dict
        "host" (.host | default $dataflowConfig.host)
        "port" (.port | default $dataflowConfig.port)
      ) $dataflowConfig -}}
    {{- end -}}
  {{- end -}}
  {{- /* Service-level external Dataflow configuration (higher priority) */ -}}
  {{- with $service.dataflow -}}
    {{- $dataflowConfig = merge (dict
      "host" (.host | default $dataflowConfig.host)
      "port" (.port | default $dataflowConfig.port)
    ) $dataflowConfig -}}
  {{- end -}}

  {{- /* Validate required configurations */ -}}
  {{- if not $dataflowConfig.host -}}
    {{- fail "Dataflow host must be set" -}}
  {{- end -}}

  {{- if not $dataflowConfig.port -}}
    {{- fail "Dataflow port must be set" -}}
  {{- end -}}

  {{- /* Ensure host has http:// prefix */ -}}
  {{- if not (hasPrefix "http://" $dataflowConfig.host) -}}
    {{- $_ := set $dataflowConfig "host" (printf "http://%s" $dataflowConfig.host) -}}
  {{- end -}}

  {{- $dataflowConfig | toYaml -}}
{{- end -}}