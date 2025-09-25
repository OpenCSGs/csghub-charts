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
{{- $ingressConfig := dict
  "enabled" ($global.Values.global.ingress.enabled | default false)
  "className" ($global.Values.global.ingress.className | default "nginx")
  "annotations" ($global.Values.global.ingress.annotations | default dict)
  "domain" ($global.Values.global.ingress.domain | default "example.com")
  "useTop" ($global.Values.global.ingress.useTop | default false)
  "tls" (dict
    "enabled" ($global.Values.global.ingress.tls.enabled | default false)
    "secretName" ($global.Values.global.ingress.tls.secretName | default "")
  )
  "service" (dict
    "type" ($global.Values.global.ingress.service.type | default "ClusterIP")
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
    {{- $serviceTls := $serviceIngress.tls -}}
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