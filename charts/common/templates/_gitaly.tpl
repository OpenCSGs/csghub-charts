{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Resolve the name of the Secret that supplies the Gitaly connection.

Resolution order: service-level gitaly.existingSecret > global.gitaly.existingSecret.
Only honored when global.gitaly.enabled=false. When set, the connection is resolved
from the Secret's GITALY_* keys (GITALY_HOST/GITALY_PORT/GITALY_TOKEN, optional
GITALY_STORAGE/GITALY_SCHEME) via lookup.

Usage:
{{ include "common.gitaly.existingSecret" (dict "ctx" . "service" .Values.servicename) }}
*/}}
{{- define "common.gitaly.existingSecret" }}
  {{- $service := .service }}
  {{- $ctx := .ctx }}
  {{- if not $ctx.Values.global.gitaly.enabled }}
    {{- $existingSecret := "" }}
    {{- with $service.gitaly }}
      {{- if .existingSecret }}
        {{- $existingSecret = .existingSecret }}
      {{- end }}
    {{- end }}
    {{- if not $existingSecret }}
      {{- with $ctx.Values.global.gitaly }}
        {{- if .existingSecret }}
          {{- $existingSecret = .existingSecret }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- $existingSecret -}}
  {{- end }}
{{- end }}

{{/*
Generate Gitaly Connection Configuration

Usage:
{{ include "common.gitaly.config" (dict "ctx" . "service" .Values.servicename) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- ctx: Global configuration values (e.g., .)

Returns: YAML configuration object with Gitaly connection parameters
*/}}
{{- define "common.gitaly.config" }}
  {{- $service := .service }}
  {{- $ctx := .ctx }}

  {{- /* Configuration priority: internal Gitaly (if enabled) > service-level external > global external */}}

  {{- /* Default configuration for internal Gitaly */}}
  {{- $gitalySvc := include "common.service" (dict "ctx" $ctx "service" "gitaly") | fromYaml }}
  {{- $gitalyName := include "common.names.custom" (list $ctx $gitalySvc.name) }}
  {{- $gitalyConfig := dict
    "host" $gitalyName
    "port" (dig "service" "port" 8075 $gitalySvc)
    "storage" (dig "storage" "default" $gitalySvc)
    "token" (include "common.randomPassword" $gitalySvc.name)
    "scheme" "tcp"
  }}

  {{- /* If internal Gitaly is enabled and secret exists, use existing token */}}
  {{- if $ctx.Values.global.gitaly.enabled }}
    {{- $secret := (lookup "v1" "Secret" $ctx.Release.Namespace $gitalyName) }}
    {{- if and $secret (index $secret.data "GITALY_TOKEN") }}
      {{- $_ := set $gitalyConfig "token" (index $secret.data "GITALY_TOKEN" | b64dec) }}
    {{- end }}
  {{- end }}

  {{- /* Override with external Gitaly configuration if internal is disabled */}}
  {{- if not $ctx.Values.global.gitaly.enabled }}
    {{- /* Global external Gitaly configuration */}}
    {{- with $ctx.Values.global.gitaly.external }}
      {{- $gitalyConfig = merge (dict
        "host" (.host | default $gitalyConfig.host)
        "port" ((.port | default $gitalyConfig.port) | toString)
        "storage" (.storage | default $gitalyConfig.storage)
        "token" (.token | default $gitalyConfig.token)
        "scheme" (.scheme | default $gitalyConfig.scheme)
      ) $gitalyConfig }}
    {{- end }}
  {{- end }}

  {{- /* Service-level external Gitaly configuration (higher priority) */}}
  {{- with $service.gitaly }}
    {{- $gitalyConfig = merge (dict
      "host" (.host | default $gitalyConfig.host)
      "port" ((.port | default $gitalyConfig.port) | toString)
      "storage" (.storage | default $gitalyConfig.storage)
      "token" (.token | default $gitalyConfig.token)
      "scheme" (.scheme | default $gitalyConfig.scheme)
    ) $gitalyConfig }}
  {{- end }}

  {{- /* existingSecret: pull real connection values from the referenced Secret. */}}
  {{- $existingSecret := include "common.gitaly.existingSecret" (dict "ctx" $ctx "service" $service) }}
  {{- if $existingSecret }}
    {{- $secretData := (lookup "v1" "Secret" $ctx.Release.Namespace $existingSecret).data | default dict }}
    {{- $realHost := dig "GITALY_HOST" "" $secretData | b64dec }}
    {{- $realPort := dig "GITALY_PORT" "" $secretData | b64dec }}
    {{- $realToken := dig "GITALY_TOKEN" "" $secretData | b64dec }}
    {{- $realStorage := dig "GITALY_STORAGE" "" $secretData | b64dec }}
    {{- $realScheme := dig "GITALY_SCHEME" "" $secretData | b64dec }}
    {{- if $realHost }}
      {{- $portValue := $gitalyConfig.port }}
      {{- if $realPort }}
        {{- $parsed := $realPort | atoi }}
        {{- if $parsed }}{{ $portValue = $parsed | toString }}{{ end }}
      {{- end }}
      {{- $gitalyConfig = dict
        "host" $realHost
        "port" $portValue
        "storage" (or $realStorage $gitalyConfig.storage)
        "token" (or $realToken $gitalyConfig.token)
        "scheme" (or $realScheme $gitalyConfig.scheme)
      }}
    {{- end }}
  {{- end }}

  {{- /* Validate required configurations */}}
  {{- if not $gitalyConfig.host }}
    {{ fail "Gitaly host must be set" }}
  {{- end }}

  {{- if not $gitalyConfig.port }}
    {{ fail "Gitaly port must be set" }}
  {{- end }}

  {{- if not $gitalyConfig.token }}
    {{ fail "Gitaly token must be set" }}
  {{- end }}

  {{- $gitalyConfig | toYaml -}}
{{- end -}}