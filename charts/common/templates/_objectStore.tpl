{{/*
Generate S3/MinIO Connection Configuration

Usage:
{{ include "common.s3.config" (dict "ctx" . "service" .Values.servicename) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- ctx: Global configuration values (e.g., .)

Returns: YAML configuration object with S3 connection parameters
*/}}
{{- define "common.s3.config" }}
  {{- $service := .service }}
  {{- $ctx := .ctx }}

  {{- /* Configuration priority: internal MinIO (if enabled) > service-level external > global external */}}

  {{- /* Default configuration (internal MinIO) */}}
  {{- $minioSvc := include "common.service" (dict "ctx" $ctx "service" "minio") | fromYaml }}
  {{- $minioName := include "common.names.custom" (list $ctx $minioSvc.name) }}
  {{- $gatewayConfig := include "common.gateway.config" (dict "ctx" $ctx "service" $service) | fromYaml }}
  {{- $s3Config := dict
    "endpoint" (printf "http://%s:%s" $minioName (dig "service" "port" 9000 $minioSvc| toString))
    "externalEndpoint" (include "common.endpoint.minio" $ctx)
    "region" (dig "region" "cn-north-1" $minioSvc)
    "accessKey" "minio"
    "secretKey" (include "common.randomPassword" $minioSvc.name)
    "bucket" (include "common.names.custom" (list $ctx $service.name))
    "encrypt" false
    "pathStyle" true
  }}
  {{- /* secure inherits its type from gateway.tls.enabled; both schemas enforce boolean. */}}
  {{- $s3Config = set $s3Config "secure" (dig "tls" "enabled" false $gatewayConfig) }}

  {{- /* If internal MinIO is enabled and secret exists, use it */}}
  {{- if $ctx.Values.global.objectStore.enabled }}
    {{- $secret := (lookup "v1" "Secret" $ctx.Release.Namespace $minioName) }}
    {{- if $secret }}
      {{- with $secret.data }}
        {{- $_ := set $s3Config "accessKey" ((.MINIO_ROOT_USER | b64dec) | default $s3Config.accessKey) }}
        {{- $_ := set $s3Config "secretKey" ((.MINIO_ROOT_PASSWORD | b64dec) | default $s3Config.secretKey) }}
      {{- end }}
    {{- end }}

  {{- else }}
    {{- /* Global external object store */}}
    {{- with $ctx.Values.global.objectStore.external }}
      {{- $s3Config = merge (dict
        "endpoint" (.endpoint | default $s3Config.endpoint)
        "externalEndpoint" (.endpoint | default $s3Config.externalEndpoint)
        "region" (.region | default $s3Config.region)
        "accessKey" (.accessKey | default $s3Config.accessKey)
        "secretKey" (.secretKey | default $s3Config.secretKey)
        "bucket" (.bucket | default $s3Config.bucket)
      ) $s3Config }}
      {{- if hasKey . "encrypt" }}
        {{- $s3Config = set $s3Config "encrypt" .encrypt }}
      {{- end }}
      {{- if hasKey . "secure" }}
        {{- $s3Config = set $s3Config "secure" .secure }}
      {{- end }}
      {{- if hasKey . "pathStyle" }}
        {{- $s3Config = set $s3Config "pathStyle" .pathStyle }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- /* Service-level external override (highest priority) */}}
  {{- with $service.objectStore }}
    {{- $s3Config = merge (dict
      "endpoint" (.endpoint | default $s3Config.endpoint)
      "externalEndpoint" (.endpoint | default $s3Config.externalEndpoint)
      "region" (.region | default $s3Config.region)
      "accessKey" (.accessKey | default $s3Config.accessKey)
      "secretKey" (.secretKey | default $s3Config.secretKey)
      "bucket" (.bucket | default $s3Config.bucket)
    ) $s3Config }}
    {{- if hasKey . "encrypt" }}
      {{- $s3Config = set $s3Config "encrypt" .encrypt }}
    {{- end }}
    {{- if hasKey . "secure" }}
      {{- $s3Config = set $s3Config "secure" .secure }}
    {{- end }}
    {{- if hasKey . "pathStyle" }}
      {{- $s3Config = set $s3Config "pathStyle" .pathStyle }}
    {{- end }}
  {{- end }}

  {{- /* Validate required configurations */}}
  {{- if not $s3Config.endpoint }}
    {{ fail "Object storage endpoint must be set" }}
  {{- end }}

  {{- if not $s3Config.accessKey }}
    {{ fail "Object storage access key must be set" }}
  {{- end }}

  {{- if not $s3Config.secretKey }}
    {{ fail "Object storage secret key must be set" }}
  {{- end }}

  {{- if not $s3Config.bucket }}
    {{ fail "Object storage bucket must be set" }}
  {{- end }}

  {{- $s3Config | toYaml -}}
{{- end -}}