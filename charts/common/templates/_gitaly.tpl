{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Gitaly Connection Configuration

Usage:
{{ include "common.gitaly.config" (dict "service" .Values.servicename "global" .) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- global: Global configuration values (e.g., .)

Returns: YAML configuration object with Gitaly connection parameters
*/}}
{{- define "common.gitaly.config" -}}
  {{- $service := .service -}}
  {{- $global := .global -}}

  {{- /* Configuration priority: internal Gitaly (if enabled) > service-level external > global external */ -}}

  {{- /* Default configuration for internal Gitaly */ -}}
  {{- $gitalySvc := include "common.service" (dict "service" "gitaly" "global" $global) | fromYaml }}
  {{- $gitalyName := include "common.names.custom" (list $global $gitalySvc.name) -}}
  {{- $gitalyConfig := dict
    "host" $gitalyName
    "port" (dig "service" "port" 8075 $gitalySvc)
    "storage" (dig "storage" "default" $gitalySvc)
    "token" (include "common.randomPassword" $gitalySvc.name)
    "scheme" "tcp"
  -}}

  {{- /* If internal Gitaly is enabled and secret exists, use existing token */ -}}
  {{- if $global.Values.global.gitaly.enabled -}}
    {{- $secret := (lookup "v1" "Secret" $global.Release.Namespace $gitalyName) -}}
    {{- if and $secret (index $secret.data "GITALY_TOKEN") -}}
      {{- $_ := set $gitalyConfig "token" (index $secret.data "GITALY_TOKEN" | b64dec) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Override with external Gitaly configuration if internal is disabled */ -}}
  {{- if not $global.Values.global.gitaly.enabled -}}
    {{- /* Global external Gitaly configuration */ -}}
    {{- with $global.Values.global.gitaly.external -}}
      {{- $gitalyConfig = merge (dict
        "host" (.host | default $gitalyConfig.host)
        "port" ((.port | default $gitalyConfig.port) | toString)
        "storage" (.storage | default $gitalyConfig.storage)
        "token" (.token | default $gitalyConfig.token)
        "scheme" (.scheme | default $gitalyConfig.scheme)
      ) $gitalyConfig -}}
    {{- end -}}
  {{- end -}}

  {{- /* Service-level external Gitaly configuration (higher priority) */ -}}
  {{- with $service.gitaly -}}
    {{- $gitalyConfig = merge (dict
      "host" (.host | default $gitalyConfig.host)
      "port" ((.port | default $gitalyConfig.port) | toString)
      "storage" (.storage | default $gitalyConfig.storage)
      "token" (.token | default $gitalyConfig.token)
      "scheme" (.scheme | default $gitalyConfig.scheme)
    ) $gitalyConfig -}}
  {{- end -}}

  {{- /* Validate required configurations */ -}}
  {{- if not $gitalyConfig.host -}}
    {{- fail "Gitaly host must be set" -}}
  {{- end -}}

  {{- if not $gitalyConfig.port -}}
    {{- fail "Gitaly port must be set" -}}
  {{- end -}}

  {{- if not $gitalyConfig.token -}}
    {{- fail "Gitaly token must be set" -}}
  {{- end -}}

  {{- $gitalyConfig | toYaml -}}
{{- end -}}