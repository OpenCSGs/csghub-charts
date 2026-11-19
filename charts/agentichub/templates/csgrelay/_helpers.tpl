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
Load and decode the Secret referenced by csgrelay.existingSecret.

The returned map is empty when no existing Secret is configured, or when the
Secret cannot be looked up (for example during `helm template`). Callers still
need to provide the normal fallback values in those cases.
*/}}
{{- define "csgrelay.existingSecretData" -}}
{{- $data := dict -}}
{{- if .Values.csgrelay.existingSecret -}}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.csgrelay.existingSecret -}}
  {{- if $secret -}}
    {{- range $key, $value := ($secret.data | default dict) -}}
      {{- $_ := set $data $key ($value | b64dec) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $data | toYaml -}}
{{- end -}}

{{/*
Validate the keys that csgrelay references from an existing Secret. The lookup
is not available during `helm template`, so this check only runs when Helm can
inspect the live Secret.
*/}}
{{- define "csgrelay.validateExistingSecret" -}}
{{- if .Values.csgrelay.existingSecret -}}
  {{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.csgrelay.existingSecret -}}
  {{- if $secret -}}
    {{- $data := $secret.data | default dict -}}
    {{- $missing := list -}}
    {{- range $key := list "tokens.toml" "nats-url" "oss-access-key-id" "oss-access-key-secret" -}}
      {{- if not (hasKey $data $key) -}}
        {{- $missing = append $missing $key -}}
      {{- end -}}
    {{- end -}}
    {{- if $missing -}}
      {{- fail (printf "csgrelay.existingSecret %q is missing required keys: %s" .Values.csgrelay.existingSecret (join ", " $missing)) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Resolve the NATS connection used by csgrelay.

Priority:
1. existingSecret key nats-url
2. csgrelay.secret.natsUrl
3. csgrelay.config.nats.url
4. common.nats.config (built-in mode only; supports bundled and external NATS)

Returns a YAML object containing the authenticated URL used by the process and
the credential-free server URL written to config.toml.
*/}}
{{- define "csgrelay.natsConfig" }}
{{- $nats := dig "config" "nats" dict .Values.csgrelay }}
{{- $existing := include "csgrelay.existingSecretData" . | fromYaml | default dict }}
{{- $url := dig "nats-url" "" $existing }}
{{- if not $url }}
  {{- $url = dig "secret" "natsUrl" "" .Values.csgrelay }}
{{- end }}
{{- if not $url }}
  {{- $url = dig "url" "" $nats }}
{{- end }}

{{- if and (not $url) .Values.global.chartContext.isBuiltIn }}
  {{- $natsConfig := include "common.nats.config" . | fromYaml }}
  {{- $url = dig "url" "" $natsConfig }}
{{- end }}

{{- if not $url }}
  {{- fail "csgrelay requires existingSecret key nats-url, csgrelay.secret.natsUrl, or csgrelay.config.nats.url when deployed standalone" }}
{{- end }}
{{- $serverUrl := regexReplaceAll "^nats://[^@]+@" $url "nats://" }}
{{- dict "url" $url "serverUrl" $serverUrl | toYaml }}
{{- end }}

{{/*
Resolve the object store configuration used by csgrelay.

Resolution:
1. existingSecret keys (oss-endpoint, oss-bucket, and related optional keys)
2. Fields explicitly set under csgrelay.config.oss / csgrelay.secret
3. global.objectStore, when present:
   - enabled=true: the bundled MinIO instance
   - enabled=false: the external S3-compatible store (for example Aliyun OSS)
4. Local csgrelay.config.oss / csgrelay.secret for standalone deployments

Aliyun OSS should normally be configured with pathStyle=false. This is mapped to
bucket_lookup=auto, while the bundled MinIO pathStyle=true is mapped to path.
*/}}
{{- define "csgrelay.s3Config" }}
{{- $service := include "common.service" (dict "ctx" . "service" "csgrelay") | fromYaml }}
{{- $oss := dig "config" "oss" dict .Values.csgrelay }}
{{- $secret := dig "secret" dict .Values.csgrelay }}
{{- $existing := include "csgrelay.existingSecretData" . | fromYaml | default dict }}
{{- $globalObjectStore := .Values.global.objectStore | default dict }}

{{- $s3Config := dict
  "endpoint" ""
  "region" "us-east-1"
  "accessKey" ""
  "secretKey" ""
  "bucket" ""
  "secure" true
  "pathStyle" true
}}
{{- if $globalObjectStore }}
  {{- $s3Config = include "common.s3.config" (dict "ctx" . "service" $service) | fromYaml }}
{{- end }}

{{- $endpoint := dig "oss-endpoint" "" $existing | default (dig "endpoint" "" $oss) | default (dig "endpoint" "" $s3Config) }}
{{- $secure := dig "secure" true $s3Config }}
{{- if hasKey $existing "oss-enable-ssl" }}
  {{- $secure = eq (toString (index $existing "oss-enable-ssl")) "true" }}
{{- else if hasKey $oss "enableSSL" }}
  {{- $secure = $oss.enableSSL }}
{{- else if hasPrefix "https://" $endpoint }}
  {{- $secure = true }}
{{- else if hasPrefix "http://" $endpoint }}
  {{- $secure = false }}
{{- end }}
{{- $endpoint = trimPrefix "https://" $endpoint }}
{{- $endpoint = trimPrefix "http://" $endpoint }}
{{- if not $endpoint }}
  {{- fail "csgrelay requires existingSecret key oss-endpoint or csgrelay.config.oss.endpoint when deployed standalone" }}
{{- end }}

{{- $bucket := dig "oss-bucket" "" $existing | default (dig "bucket" "" $oss) | default (dig "bucket" "" $s3Config) }}
{{- if not $bucket }}
  {{- fail "csgrelay requires existingSecret key oss-bucket or csgrelay.config.oss.bucket" }}
{{- end }}

{{- $bucketLookup := dig "oss-bucket-lookup" "" $existing }}
{{- if not $bucketLookup }}
  {{- $bucketLookup = dig "bucketLookup" "" $oss }}
{{- end }}
{{- if not $bucketLookup }}
  {{- $bucketLookup = "path" }}
  {{- if or (and $globalObjectStore (eq (toString (dig "pathStyle" true $s3Config)) "false")) (contains "aliyuncs.com" $endpoint) }}
    {{- $bucketLookup = "auto" }}
  {{- end }}
{{- end }}

{{- dict
  "endpoint" $endpoint
  "region" (dig "oss-region" "" $existing | default (dig "region" "" $oss) | default (dig "region" "us-east-1" $s3Config))
  "accessKey" (dig "oss-access-key-id" "" $existing | default (dig "ossAccessKeyId" "" $secret) | default (dig "accessKey" "" $s3Config))
  "secretKey" (dig "oss-access-key-secret" "" $existing | default (dig "ossAccessKeySecret" "" $secret) | default (dig "secretKey" "" $s3Config))
  "bucket" $bucket
  "secure" $secure
  "bucketLookup" $bucketLookup
  "prefix" (dig "oss-prefix" "" $existing | default (dig "prefix" "csgrelay/" $oss))
  "credentials" (dig "oss-credentials" "" $existing | default (dig "credentials" "env" $oss))
  | toYaml }}
{{- end }}
