{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Resolve the Secret used by csgrelay.
*/}}
{{- define "csgrelay.secretName" -}}
{{- $service := include "common.service" (dict "ctx" . "service" "csgrelay") | fromYaml }}
{{- if .Values.csgrelay.existingSecret }}
{{- .Values.csgrelay.existingSecret }}
{{- else }}
{{- include "common.names.custom" (list . $service.name) }}
{{- end }}
{{- end }}

{{/*
Resolve the NATS connection used by csgrelay.

Priority:
1. csgrelay.secret.natsUrl
2. csgrelay.config.nats.url
3. CSGHub bundled NATS configuration (built-in mode only)

Returns a YAML object containing the authenticated URL used by the process and
the credential-free server URL written to config.toml.
*/}}
{{- define "csgrelay.natsConfig" }}
{{- $nats := dig "config" "nats" dict .Values.csgrelay }}
{{- $url := dig "secret" "natsUrl" "" .Values.csgrelay }}
{{- if not $url }}
  {{- $url = dig "url" "" $nats }}
{{- end }}

{{- if and (not $url) .Values.global.chartContext.isBuiltIn }}
  {{- $globalNats := dig "nats" dict .Values.global }}
  {{- if dig "enabled" true $globalNats }}
    {{- $natsConfig := include "common.nats.config" . | fromYaml }}
    {{- $auth := "" }}
    {{- if $natsConfig.user }}
      {{- $auth = printf "%s:%s@" ($natsConfig.user | urlquery | replace "+" "%20") ($natsConfig.password | urlquery | replace "+" "%20") }}
    {{- end }}
    {{- $host := $natsConfig.host }}
    {{- if and (contains ":" $host) (not (hasPrefix "[" $host)) }}
      {{- $host = printf "[%s]" $host }}
    {{- end }}
    {{- $url = printf "nats://%s%s:%v" $auth $host $natsConfig.port }}
  {{- else }}
    {{- $external := dig "external" dict $globalNats }}
    {{- $url = dig "url" "" $external }}
    {{- if not $url }}
      {{- $host := required "global.nats.external.url or global.nats.external.host must be set when global.nats.enabled=false" (dig "host" "" $external) }}
      {{- $port := dig "port" 4222 $external }}
      {{- $user := dig "user" "" $external }}
      {{- $password := dig "password" "" $external }}
      {{- $auth := "" }}
      {{- if $user }}
        {{- $auth = printf "%s:%s@" ($user | urlquery | replace "+" "%20") ($password | urlquery | replace "+" "%20") }}
      {{- end }}
      {{- if and (contains ":" $host) (not (hasPrefix "[" $host)) }}
        {{- $host = printf "[%s]" $host }}
      {{- end }}
      {{- $url = printf "nats://%s%s:%v" $auth $host $port }}
    {{- end }}
  {{- end }}
{{- end }}

{{- if not $url }}
  {{- fail "csgrelay requires csgrelay.secret.natsUrl or csgrelay.config.nats.url when deployed standalone" }}
{{- end }}
{{- $serverUrl := regexReplaceAll "^nats://[^@]+@" $url "nats://" }}
{{- dict "url" $url "serverUrl" $serverUrl | toYaml }}
{{- end }}

{{/*
Resolve the object store configuration used by csgrelay.

Resolution:
1. Fields explicitly set under csgrelay.config.oss / csgrelay.secret
2. global.objectStore, when present:
   - enabled=true: the bundled MinIO instance
   - enabled=false: the external S3-compatible store (for example Aliyun OSS)
3. Local csgrelay.config.oss / csgrelay.secret for standalone deployments

Aliyun OSS should normally be configured with pathStyle=false. This is mapped to
bucket_lookup=auto, while the bundled MinIO pathStyle=true is mapped to path.
*/}}
{{- define "csgrelay.s3Config" }}
{{- $service := include "common.service" (dict "ctx" . "service" "csgrelay") | fromYaml }}
{{- $oss := dig "config" "oss" dict .Values.csgrelay }}
{{- $secret := dig "secret" dict .Values.csgrelay }}
{{- $useGlobalObjectStore := hasKey .Values.global "objectStore" }}

{{- $s3Config := dict
  "endpoint" ""
  "region" "us-east-1"
  "accessKey" ""
  "secretKey" ""
  "bucket" ""
  "secure" true
  "pathStyle" true
}}
{{- if $useGlobalObjectStore }}
  {{- $s3Config = include "common.s3.config" (dict "ctx" . "service" $service) | fromYaml }}
{{- end }}

{{- $endpoint := dig "endpoint" "" $oss | default (dig "endpoint" "" $s3Config) }}
{{- $secure := dig "secure" true $s3Config }}
{{- if hasKey $oss "enableSSL" }}
  {{- $secure = $oss.enableSSL }}
{{- else if hasPrefix "https://" $endpoint }}
  {{- $secure = true }}
{{- else if hasPrefix "http://" $endpoint }}
  {{- $secure = false }}
{{- end }}
{{- $endpoint = trimPrefix "https://" $endpoint }}
{{- $endpoint = trimPrefix "http://" $endpoint }}
{{- if not $endpoint }}
  {{- fail "csgrelay requires csgrelay.config.oss.endpoint when deployed standalone" }}
{{- end }}

{{- $bucket := dig "bucket" "" $oss | default (dig "bucket" "" $s3Config) }}
{{- if not $bucket }}
  {{- fail "csgrelay requires csgrelay.config.oss.bucket" }}
{{- end }}

{{- $bucketLookup := dig "bucketLookup" "" $oss }}
{{- if not $bucketLookup }}
  {{- $bucketLookup = "path" }}
  {{- if or (and $useGlobalObjectStore (hasKey $s3Config "pathStyle") (not $s3Config.pathStyle)) (contains "aliyuncs.com" $endpoint) }}
    {{- $bucketLookup = "auto" }}
  {{- end }}
{{- end }}

{{- dict
  "endpoint" $endpoint
  "region" (dig "region" "" $oss | default (dig "region" "us-east-1" $s3Config))
  "accessKey" (dig "ossAccessKeyId" "" $secret | default (dig "accessKey" "" $s3Config))
  "secretKey" (dig "ossAccessKeySecret" "" $secret | default (dig "secretKey" "" $s3Config))
  "bucket" $bucket
  "secure" $secure
  "bucketLookup" $bucketLookup
  "prefix" (dig "prefix" "csgrelay/" $oss)
  "credentials" (dig "credentials" "env" $oss)
  | toYaml }}
{{- end }}
