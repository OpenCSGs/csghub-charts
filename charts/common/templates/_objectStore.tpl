{{/*
Resolve the name of the Secret that supplies the object store connection.

Resolution order: service-level objectStore.existingSecret > global.objectStore.existingSecret.
Only honored when global.objectStore.enabled=false. When set, the connection is resolved
from the Secret's OBJECT_STORE_* keys (OBJECT_STORE_ENDPOINT/OBJECT_STORE_ACCESS_KEY/
OBJECT_STORE_SECRET_KEY, optional OBJECT_STORE_REGION/OBJECT_STORE_BUCKET) via lookup.

Usage:
{{ include "common.objectStore.existingSecret" (dict "ctx" . "service" .Values.servicename) }}
*/}}
{{- define "common.objectStore.existingSecret" }}
  {{- $service := .service }}
  {{- $ctx := .ctx }}
  {{- if not $ctx.Values.global.objectStore.enabled }}
    {{- $existingSecret := "" }}
    {{- with $service.objectStore }}
      {{- if .existingSecret }}
        {{- $existingSecret = .existingSecret }}
      {{- end }}
    {{- end }}
    {{- if not $existingSecret }}
      {{- with $ctx.Values.global.objectStore }}
        {{- if .existingSecret }}
          {{- $existingSecret = .existingSecret }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- $existingSecret -}}
  {{- end }}
{{- end }}

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

  {{- /* existingSecret: pull real connection values from the referenced Secret. */}}
  {{- $existingSecret := include "common.objectStore.existingSecret" (dict "ctx" $ctx "service" $service) }}
  {{- if $existingSecret }}
    {{- $secretData := (lookup "v1" "Secret" $ctx.Release.Namespace $existingSecret).data | default dict }}
    {{- $realEndpoint := dig "OBJECT_STORE_ENDPOINT" "" $secretData | b64dec }}
    {{- $realAccessKey := dig "OBJECT_STORE_ACCESS_KEY" "" $secretData | b64dec }}
    {{- $realSecretKey := dig "OBJECT_STORE_SECRET_KEY" "" $secretData | b64dec }}
    {{- $realRegion := dig "OBJECT_STORE_REGION" "" $secretData | b64dec }}
    {{- $realBucket := dig "OBJECT_STORE_BUCKET" "" $secretData | b64dec }}
    {{- if $realEndpoint }}
      {{- $s3Config = dict
        "endpoint" $realEndpoint
        "externalEndpoint" $realEndpoint
        "region" (or $realRegion $s3Config.region)
        "accessKey" (or $realAccessKey $s3Config.accessKey)
        "secretKey" (or $realSecretKey $s3Config.secretKey)
        "bucket" (or $realBucket $s3Config.bucket)
        "encrypt" $s3Config.encrypt
        "secure" $s3Config.secure
        "pathStyle" $s3Config.pathStyle
      }}
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