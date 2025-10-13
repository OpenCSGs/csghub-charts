{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate NATS Connection Configuration

Usage:
{{ include "common.nats.config" . }}

Parameters:
- global: Global configuration values (e.g., .)

Returns: YAML configuration object with NATS connection parameters
*/}}
{{- define "common.nats.config" -}}
  {{- $global := . -}}

  {{- /* Configuration priority: internal NATS > external NATS */ -}}

  {{- /* Default configuration for internal NATS */ -}}
  {{- $natsSvc := include "common.service" (dict "service" "nats" "global" $global) | fromYaml }}
  {{- $natsName := include "common.names.custom" (list $global $natsSvc.name) -}}
  {{- $natsConfig := dict
    "host" $natsName
    "port" (dig "service" "port" 4222 $natsSvc)
    "user" "natsadmin"
    "password" (include "common.randomPassword" $natsSvc.name)
  -}}

  {{- /* If secret exists, use existing credentials */ -}}
  {{- $secret := (lookup "v1" "Secret" $global.Release.Namespace $natsName) -}}
  {{- if and $secret (index $secret.data "NATS_PASSWORD") -}}
    {{- $_ := set $natsConfig "password" (index $secret.data "NATS_PASSWORD" | b64dec) -}}
  {{- end -}}
  {{- if and $secret (index $secret.data "NATS_USERNAME") -}}
    {{- $_ := set $natsConfig "user" (index $secret.data "NATS_USERNAME" | b64dec) -}}
  {{- end -}}

  {{- /* Validate required configurations */ -}}
  {{- if not $natsConfig.password -}}
    {{- fail "NATS password must be set" -}}
  {{- end -}}

  {{- if not $natsConfig.host -}}
    {{- fail "NATS host must be set" -}}
  {{- end -}}

  {{- $natsConfig | toYaml -}}
{{- end -}}