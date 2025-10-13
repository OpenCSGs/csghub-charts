{{/*
Generate S3/MinIO Connection Configuration

Usage:
{{ include "common.s3.config" (dict "service" .Values.servicename "global" .) }}

Parameters:
- service: Service-specific configuration values (e.g., .Values.api)
- global: Global configuration values (e.g., .)

Returns: YAML configuration object with S3 connection parameters
*/}}
{{- define "common.s3.config" -}}
  {{- $service := .service -}}
  {{- $global := .global -}}

  {{- /* Configuration priority: internal MinIO (if enabled) > service-level external > global external */ -}}

  {{- /* Default configuration (internal MinIO) */ -}}
  {{- $minioSvc := include "common.service" (dict "service" "minio" "global" $global) | fromYaml }}
  {{- $minioName := include "common.names.custom" (list $global $minioSvc.name) -}}
  {{- $ingressConfig := include "common.ingress.config" (dict "service" $service "global" $global) | fromYaml }}
  {{- $s3Config := dict
    "endpoint" (printf "http://%s:%s" $minioName (dig "service" "port" "9000" $minioSvc| toString))
    "externalEndpoint" (include "common.endpoint.minio" $global)
    "region" (dig "region" "cn-north-1" $minioSvc)
    "accessKey" "minio"
    "secretKey" (include "common.randomPassword" $minioSvc.name)
    "bucket" (include "common.names.custom" (list $global $service.name))
    "encrypt" "false"
    "secure" (dig "tls" "enabled" "false" $ingressConfig)
    "pathStyle" "true"
  -}}

  {{- /* If internal MinIO is enabled and secret exists, use it */ -}}
  {{- if $global.Values.global.objectStore.enabled -}}
    {{- $secret := (lookup "v1" "Secret" $global.Release.Namespace $minioName) -}}
    {{- if $secret -}}
      {{- with $secret.data -}}
        {{- $_ := set $s3Config "accessKey" ((.MINIO_ROOT_USER | b64dec) | default $s3Config.accessKey) -}}
        {{- $_ := set $s3Config "secretKey" ((.MINIO_ROOT_PASSWORD | b64dec) | default $s3Config.secretKey) -}}
      {{- end -}}
    {{- end -}}

  {{- else -}}
    {{- /* Global external object store */ -}}
    {{- with $global.Values.global.objectStore.external -}}
      {{- $s3Config = merge (dict
        "endpoint" (.endpoint | default $s3Config.endpoint)
        "externalEndpoint" (.endpoint | default $s3Config.externalEndpoint)
        "region" (.region | default $s3Config.region)
        "accessKey" (.accessKey | default $s3Config.accessKey)
        "secretKey" (.secretKey | default $s3Config.secretKey)
        "bucket" (.bucket | default $s3Config.bucket)
        "encrypt" (.encrypt | default $s3Config.encrypt)
        "secure" (.secure | default $s3Config.secure)
        "pathStyle" (.pathStyle | default $s3Config.pathStyle)
      ) $s3Config -}}
    {{- end -}}

    {{- /* Service-level external override (highest priority) */ -}}
    {{- with $service.objectStore -}}
      {{- $s3Config = merge (dict
        "endpoint" (.endpoint | default $s3Config.endpoint)
        "externalEndpoint" (.endpoint | default $s3Config.externalEndpoint)
        "region" (.region | default $s3Config.region)
        "accessKey" (.accessKey | default $s3Config.accessKey)
        "secretKey" (.secretKey | default $s3Config.secretKey)
        "bucket" (.bucket | default $s3Config.bucket)
        "encrypt" (.encrypt | default $s3Config.encrypt)
        "secure" (.secure | default $s3Config.secure)
        "pathStyle" (.pathStyle | default $s3Config.pathStyle)
      ) $s3Config -}}
    {{- end -}}
  {{- end -}}

  {{- /* Validate required configurations */ -}}
  {{- if not $s3Config.endpoint -}}
    {{- fail "Object storage endpoint must be set" -}}
  {{- end -}}

  {{- if not $s3Config.accessKey -}}
    {{- fail "Object storage access key must be set" -}}
  {{- end -}}

  {{- if not $s3Config.secretKey -}}
    {{- fail "Object storage secret key must be set" -}}
  {{- end -}}

  {{- if not $s3Config.bucket -}}
    {{- fail "Object storage bucket must be set" -}}
  {{- end -}}

  {{- $s3Config | toYaml -}}
{{- end -}}