{{- /*
Copyright Broadcom, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Gateway API Configuration with proper merging logic

Usage:
{{ include "common.gateway.config" (dict "ctx" . "service" .Values.webapp) }}

Parameters:
- service: Service-specific gateway configuration (from .Values.<service>)
- ctx: Global helm context (the root context)

Returns: YAML configuration with merged gateway settings
*/}}
{{- define "common.gateway.config" }}
  {{- $ctx := .ctx }}
  {{- $service := .service }}

  {{- /* Configuration priority: service-level gateway > global gateway */}}

  {{- /* Default configuration from global gateway */}}
  {{- $globalGateway := $ctx.Values.global.gateway }}
  {{- $gatewayConfig := dict
    "enabled" (dig "enabled" false $globalGateway)
    "controllerName" (dig "controllerName" "nginx" $globalGateway)
    "tls" (dict
      "enabled" (dig "tls" "enabled" false $globalGateway)
      "secretName" (dig "tls" "secretName" "" $globalGateway)
    )
    "service" (dict
      "type" (dig "service" "type" "LoadBalancer" $globalGateway)
      "nodePorts" (dict
        "http" (dig "service" "nodePorts" "http" "30080" $globalGateway)
        "https" (dig "service" "nodePorts" "https" "30443" $globalGateway)
        "gitssh" (dig "service" "nodePorts" "gitssh" "30022" $globalGateway)
      )
    )
    "basicAuth" (dict
      "username" (dig "basicAuth" "username" "" $globalGateway)
      "password" (dig "basicAuth" "password" "" $globalGateway)
    )
  }}

  {{- /* Service-level gateway configuration (higher priority) */}}
  {{- with $service.gateway }}
    {{- $gatewayConfig = merge (dict
      "enabled" (.enabled | default $gatewayConfig.enabled)
      "controllerName" (.controllerName | default $gatewayConfig.controllerName)
      "tls" (dict
        "enabled" (dig "tls" "enabled" $gatewayConfig.tls.enabled .)
        "secretName" (dig "tls" "secretName" $gatewayConfig.tls.secretName . )
      )
      "service" (dict
        "type" (dig "service" "type" $gatewayConfig.service.type .)
        "nodePorts" (dict
          "http" (dig "service" "nodePorts" "http" $gatewayConfig.service.nodePorts.http . )
          "https" (dig "service" "nodePorts" "https" $gatewayConfig.service.nodePorts.https . )
          "gitssh" (dig "service" "nodePorts" "gitssh" $gatewayConfig.service.nodePorts.gitssh .)
        )
      )
      "basicAuth" (dict
        "username" (dig "basicAuth" "username" $gatewayConfig.basicAuth.username .)
        "password" (dig "basicAuth" "password" "" $gatewayConfig.basicAuth.password .)
      )
    ) $gatewayConfig }}
  {{- end }}

  {{- if and $gatewayConfig.enabled $gatewayConfig.tls.enabled (not $gatewayConfig.tls.secretName) }}
    {{ fail "TLS secretName must be set when TLS is enabled" }}
  {{- end }}

  {{- $gatewayConfig | toYaml -}}
{{- end -}}