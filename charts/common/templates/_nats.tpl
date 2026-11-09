{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate NATS Connection Configuration

Usage:
{{ include "common.nats.config" . }}

Parameters:
- ctx: Global configuration values (e.g., .)

Returns: YAML configuration object with NATS connection parameters and a URL.
External URL takes precedence over host/port/user/password. Missing global.nats
preserves the built-in behavior for charts using older values.
*/}}
{{- define "common.nats.config" }}
  {{- $ctx := . }}

  {{- if not (dig "nats" "enabled" true $ctx.Values.global) }}
    {{- $external := dig "nats" "external" (dict) $ctx.Values.global }}
    {{- $url := $external.url | default "" | trim }}
    {{- $host := $external.host | default "" | trim }}
    {{- $port := $external.port | default 4222 }}
    {{- $user := $external.user | default "" }}
    {{- $password := $external.password | default "" }}
    {{- if not $url }}
      {{- if not $host }}
        {{- fail "global.nats.external.url or global.nats.external.host must be set when global.nats.enabled=false" }}
      {{- end }}
      {{- $auth := "" }}
      {{- if $user }}
        {{- $auth = printf "%s:%s@" ($user | urlquery | replace "+" "%20") ($password | urlquery | replace "+" "%20") }}
      {{- else if $password }}
        {{- fail "global.nats.external.user must be set when global.nats.external.password is provided" }}
      {{- end }}
      {{- $urlHost := $host }}
      {{- if and (contains ":" $host) (not (hasPrefix "[" $host)) }}
        {{- $urlHost = printf "[%s]" $host }}
      {{- end }}
      {{- $url = printf "nats://%s%s:%v" $auth $urlHost $port }}
    {{- end }}
    {{- dict "host" $host "port" $port "user" $user "password" $password "url" $url | toYaml }}
  {{- else }}

    {{- /* Default configuration for internal NATS */}}
    {{- $natsSvc := include "common.service" (dict "ctx" $ctx "service" "nats") | fromYaml }}
    {{- $natsName := include "common.names.custom" (list $ctx $natsSvc.name) }}
    {{- $natsConfig := dict
      "host" $natsName
      "port" (dig "service" "port" 4222 $natsSvc)
      "user" "natsadmin"
      "password" (include "common.secret.password" (list $ctx (printf "%s.password" $natsSvc.name) 32))
    }}

    {{- /* If secret exists, use existing credentials */}}
    {{- $secret := (lookup "v1" "Secret" $ctx.Release.Namespace $natsName)}}
    {{- if and $secret (index $secret.data "NATS_PASSWORD") }}
      {{- $_ := set $natsConfig "password" (index $secret.data "NATS_PASSWORD" | b64dec) }}
    {{- end }}
    {{- if and $secret (index $secret.data "NATS_USERNAME") }}
      {{- $_ := set $natsConfig "user" (index $secret.data "NATS_USERNAME" | b64dec) }}
    {{- end }}

    {{- /* Validate required configurations */}}
    {{- if not $natsConfig.password }}
      {{ fail "NATS password must be set" }}
    {{- end }}

    {{- if not $natsConfig.host }}
      {{ fail "NATS host must be set" }}
    {{- end }}

    {{- $_ := set $natsConfig "url" (printf "nats://%s:%s@%s:%v" $natsConfig.user $natsConfig.password $natsConfig.host $natsConfig.port) }}
    {{- $natsConfig | toYaml -}}
  {{- end }}
{{- end -}}
