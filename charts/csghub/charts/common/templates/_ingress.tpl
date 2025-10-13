{{- /*
Copyright Broadcom, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Ingress Configuration with proper merging logic

Usage:
{{ include "common.ingress.config" (dict "service" .Values.webapp "global" .) }}

Parameters:
- service: Service-specific ingress configuration (from .Values.<service>)
- global: Global helm context (the root context)

Returns: YAML configuration with merged ingress settings
*/}}
{{- define "common.ingress.config" -}}
{{- $service := .service -}}
{{- $global := .global -}}

{{- /* Configuration priority: service-level ingress > global ingress */ -}}

{{- /* Default configuration from global ingress */ -}}
{{- $globalIngress := $global.Values.global.ingress }}
{{- $ingressConfig := dict
  "enabled" (dig "enabled" "false" $globalIngress)
  "className" (dig "className" "nginx" $globalIngress)
  "annotations" (dig "annotations" dict $globalIngress)
  "domain" (dig "domain" "example.com" $globalIngress)
  "useTop" (dig "useTop" "false" $globalIngress)
  "tls" (dict
    "enabled" (dig "tls" "enabled" "false" $globalIngress)
    "secretName" (dig "tls" "secretName" "" $globalIngress)
  )
  "service" (dict
    "type" (dig "service" "type" "LoadBalancer" $globalIngress)
  )
-}}

{{- /* Merge with service-level ingress configuration (higher priority) */ -}}
{{- if $service.ingress -}}
  {{- $serviceIngress := $service.ingress -}}

  {{- /* Merge basic fields */ -}}
  {{- if hasKey $serviceIngress "enabled" -}}
    {{- $_ := set $ingressConfig "enabled" $serviceIngress.enabled -}}
  {{- end -}}

  {{- /* Merge annotations */ -}}
  {{- if hasKey $serviceIngress "annotations" -}}
    {{- $mergedAnnotations := merge $ingressConfig.annotations $serviceIngress.annotations -}}
    {{- $_ := set $ingressConfig "annotations" $mergedAnnotations -}}
  {{- end -}}

  {{- /* Merge TLS configuration */ -}}
  {{- if hasKey $serviceIngress "tls" -}}
    {{- $serviceTls := dict }}
    {{- with $service.ingress.tls }}
      {{- if kindIs "slice" . }}
        {{- if . }}
          {{- $serviceTls = first . }}
        {{- else }}
          {{- $serviceTls = dict "enabled" false }}
        {{- end }}
      {{- else if kindIs "map" . }}
        {{- $serviceTls = . }}
      {{- end }}
    {{- end -}}

    {{- $mergedTls := $ingressConfig.tls -}}

    {{- if hasKey $serviceTls "enabled" -}}
      {{- $_ := set $mergedTls "enabled" $serviceTls.enabled -}}
    {{- end -}}

    {{- if hasKey $serviceTls "secretName" -}}
      {{- $_ := set $mergedTls "secretName" $serviceTls.secretName -}}
    {{- end -}}

    {{- $_ := set $ingressConfig "tls" $mergedTls -}}
  {{- end -}}
{{- end -}}

{{- /* Validate required configurations */ -}}
{{- if and $ingressConfig.enabled (not $ingressConfig.domain) -}}
  {{- fail "Ingress domain must be set when ingress is enabled" -}}
{{- end -}}

{{- if and $ingressConfig.enabled $ingressConfig.tls.enabled (not $ingressConfig.tls.secretName) -}}
  {{- fail "TLS secretName must be set when TLS is enabled" -}}
{{- end -}}

{{- $ingressConfig | toYaml -}}
{{- end -}}