{{- /*
Copyright OpenCSG, Inc.
All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Registry Configuration

Usage:
{{ include "common.registry.config" (dict "service" .Values.servicename "global" .) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- global: Global configuration values (e.g., .)

Configuration priority:
1. Internal registry (if enabled)
2. Service-level external registry (override global)
3. Global external registry

Returns: YAML configuration object with registry parameters
*/}}
{{- define "common.registry.config" -}}
  {{- $service := .service -}}
  {{- $global := .global -}}

  {{- /* Default configuration for internal registry */ -}}
  {{- $registrySvc := include "common.service" (dict "service" "registry" "global" $global) | fromYaml -}}
  {{- $registryName := include "common.names.custom" (list $global $registrySvc.name) -}}
  {{- $registryConfig := dict
    "registry" (include "common.domain.csghub" $global)
    "repository" $global.Release.Namespace
    "username" "registry"
    "password" (include "common.randomPassword" $registrySvc.name)
    "insecure" "false"
  -}}

  {{- /* If internal registry is enabled and secret exists, use existing credentials */ -}}
  {{- if $global.Values.global.registry.enabled -}}
    {{- $secret := lookup "v1" "Secret" $global.Release.Namespace $registryName -}}
    {{- if and $secret $secret.data -}}
      {{- $_ := set $registryConfig "username" ((index $secret.data "REGISTRY_USERNAME" | b64dec) | default $registryConfig.username) -}}
      {{- $_ := set $registryConfig "password" ((index $secret.data "REGISTRY_PASSWORD" | b64dec) | default $registryConfig.password) -}}
    {{- end -}}
  {{- end -}}

  {{- /* Override with external registry configuration if internal is disabled */ -}}
  {{- if not $global.Values.global.registry.enabled -}}
    {{- /* Global external registry configuration */ -}}
    {{- with $global.Values.global.registry.external -}}
      {{- $registryConfig = merge (dict
        "registry" (.registry | default $registryConfig.registry)
        "repository" (.repository | default $registryConfig.repository)
        "username" (.username | default $registryConfig.username)
        "password" (.password | default $registryConfig.password)
        "insecure" (.insecure | default $registryConfig.insecure)
      ) $registryConfig -}}
    {{- end -}}

    {{- /* Service-level external registry configuration (higher priority) */ -}}
    {{- with $service.registry -}}
      {{- $registryConfig = merge (dict
        "registry" (.registry | default $registryConfig.registry)
        "repository" (.repository | default $registryConfig.repository)
        "username" (.username | default $registryConfig.username)
        "password" (.password | default $registryConfig.password)
        "insecure" (.insecure | default $registryConfig.insecure)
      ) $registryConfig -}}
    {{- end -}}
  {{- end -}}

  {{- /* Validate required configurations */ -}}
  {{- if not $registryConfig.registry -}}
    {{- fail "Registry endpoint must be set" -}}
  {{- end -}}

  {{- if not $registryConfig.repository -}}
    {{- fail "Registry repository must be set" -}}
  {{- end -}}

  {{- if not $registryConfig.username -}}
    {{- fail "Registry username must be set" -}}
  {{- end -}}

  {{- if not $registryConfig.password -}}
    {{- fail "Registry password must be set" -}}
  {{- end -}}

  {{- $registryConfig | toYaml -}}
{{- end -}}