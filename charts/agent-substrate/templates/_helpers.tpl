{{/*
Expand the name of the chart.
*/}}
{{- define "agent-substrate.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "agent-substrate.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "agent-substrate.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "agent-substrate.labels" -}}
helm.sh/chart: {{ include "agent-substrate.chart" . }}
app.kubernetes.io/name: {{ include "agent-substrate.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Resolve a Substrate component image.
Usage: {{ include "agent-substrate.image" (dict "root" . "name" "ateapi") }}
*/}}
{{- define "agent-substrate.image" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $repo := $root.Values.images.repo -}}
{{- $tag := $root.Values.images.tag -}}
{{- $override := index (default dict $root.Values.images.overrides) $name | default dict -}}
{{- if $override.repository }}{{ $repo = $override.repository }}{{ end -}}
{{- if $override.tag }}{{ $tag = $override.tag }}{{ end -}}
{{- if $override.digest -}}
{{ printf "%s/%s@%s" $repo $name $override.digest }}
{{- else -}}
{{ printf "%s/%s:%s" $repo $name $tag }}
{{- end -}}
{{- end }}

{{- define "agent-substrate.agentgatewayImage" -}}
{{- $img := .Values.agentgateway.image -}}
{{- if $img.digest -}}
{{ printf "%s:%s@%s" $img.repository $img.tag $img.digest }}
{{- else -}}
{{ printf "%s:%s" $img.repository $img.tag }}
{{- end -}}
{{- end }}

{{/*
Managed object-store Secret name when the chart creates one from values.
*/}}
{{- define "agent-substrate.objectStore.managedSecretName" -}}
{{- printf "%s-objectstore" (include "agent-substrate.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Operator-supplied existingSecret name.
Order: objectStore.existingSecret > global.objectStore.existingSecret
(only when global.objectStore.enabled is false/absent — same rule as common).
*/}}
{{- define "agent-substrate.objectStore.existingSecret" -}}
{{- $secret := .Values.objectStore.existingSecret | default "" -}}
{{- if not $secret -}}
{{- if and .Values.global .Values.global.objectStore (not .Values.global.objectStore.enabled) -}}
{{- $secret = .Values.global.objectStore.existingSecret | default "" -}}
{{- end -}}
{{- end -}}
{{- $secret -}}
{{- end }}

{{/*
Resolve S3 connection fields from chart objectStore, then global.objectStore.external.
Returns a dict: endpoint, region, pathStyle, accessKey, secretKey, bucket.
*/}}
{{- define "agent-substrate.objectStore.config" -}}
{{- $os := .Values.objectStore | default dict -}}
{{- $ext := dict -}}
{{- if and .Values.global .Values.global.objectStore (not .Values.global.objectStore.enabled) -}}
{{- $ext = .Values.global.objectStore.external | default dict -}}
{{- end -}}
{{- $cfg := dict
  "endpoint" ($os.endpoint | default $ext.endpoint | default "")
  "region" ($os.region | default $ext.region | default "cn-north-1")
  "accessKey" ($os.accessKey | default $ext.accessKey | default "")
  "secretKey" ($os.secretKey | default $ext.secretKey | default "")
  "bucket" ($os.bucket | default $ext.bucket | default "")
  "pathStyle" (hasKey $os "pathStyle" | ternary $os.pathStyle (hasKey $ext "pathStyle" | ternary $ext.pathStyle true))
-}}
{{- $existingSecret := include "agent-substrate.objectStore.existingSecret" . -}}
{{- if $existingSecret -}}
{{- $secretData := (lookup "v1" "Secret" .Release.Namespace $existingSecret).data | default dict -}}
{{- $realEndpoint := dig "OBJECT_STORE_ENDPOINT" "" $secretData | b64dec -}}
{{- $realAccessKey := dig "OBJECT_STORE_ACCESS_KEY" "" $secretData | b64dec -}}
{{- $realSecretKey := dig "OBJECT_STORE_SECRET_KEY" "" $secretData | b64dec -}}
{{- $realRegion := dig "OBJECT_STORE_REGION" "" $secretData | b64dec -}}
{{- $realBucket := dig "OBJECT_STORE_BUCKET" "" $secretData | b64dec -}}
{{- if $realEndpoint -}}{{- $_ := set $cfg "endpoint" $realEndpoint -}}{{- end -}}
{{- if $realAccessKey -}}{{- $_ := set $cfg "accessKey" $realAccessKey -}}{{- end -}}
{{- if $realSecretKey -}}{{- $_ := set $cfg "secretKey" $realSecretKey -}}{{- end -}}
{{- if $realRegion -}}{{- $_ := set $cfg "region" $realRegion -}}{{- end -}}
{{- if $realBucket -}}{{- $_ := set $cfg "bucket" $realBucket -}}{{- end -}}
{{- end -}}
{{- $cfg | toYaml -}}
{{- end }}

{{/*
True when Helm should create the OBJECT_STORE_* Secret from inline values.
*/}}
{{- define "agent-substrate.objectStore.createSecret" -}}
{{- $existing := include "agent-substrate.objectStore.existingSecret" . -}}
{{- $cfg := include "agent-substrate.objectStore.config" . | fromYaml -}}
{{- if and (not $existing) $cfg.accessKey $cfg.secretKey -}}
true
{{- end -}}
{{- end }}

{{/*
Secret name used by objectstore-plugin: existingSecret, else managed, else empty.
*/}}
{{- define "agent-substrate.objectStore.secretName" -}}
{{- $existing := include "agent-substrate.objectStore.existingSecret" . -}}
{{- if $existing -}}
{{- $existing -}}
{{- else if eq (include "agent-substrate.objectStore.createSecret" .) "true" -}}
{{- include "agent-substrate.objectStore.managedSecretName" . -}}
{{- end -}}
{{- end }}

{{/*
Cluster snapshot location. Values win; otherwise gs://{{ bucket }}/.
*/}}
{{- define "agent-substrate.objectStore.snapshotLocation" -}}
{{- $os := .Values.objectStore | default dict -}}
{{- if $os.snapshotLocation -}}
{{- $os.snapshotLocation -}}
{{- else -}}
{{- $cfg := include "agent-substrate.objectStore.config" . | fromYaml -}}
{{- if $cfg.bucket -}}
{{- printf "gs://%s/" $cfg.bucket -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Object-store plugin env for S3/GCS. Indent with nindent at call site.
Always mounts credentials from a Secret (existing or chart-managed).
*/}}
{{- define "agent-substrate.objectstoreEnv" -}}
{{- $os := .Values.objectStore -}}
{{- $cfg := include "agent-substrate.objectStore.config" . | fromYaml -}}
{{- $secretName := include "agent-substrate.objectStore.secretName" . -}}
{{- if and (eq $os.backend "s3") (not $secretName) -}}
{{- fail "objectStore: set existingSecret, or accessKey+secretKey (chart creates the Secret), or global.objectStore.existingSecret" -}}
{{- end -}}
- name: ATE_STORAGE_BACKEND
  value: {{ $os.backend | quote }}
{{- if eq $os.backend "s3" }}
- name: AWS_REGION
  value: {{ $cfg.region | quote }}
{{- if $cfg.endpoint }}
- name: AWS_ENDPOINT_URL
  value: {{ $cfg.endpoint | quote }}
{{- end }}
- name: AWS_S3_USE_PATH_STYLE
  value: {{ $cfg.pathStyle | ternary "true" "false" | quote }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: OBJECT_STORE_ACCESS_KEY
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: OBJECT_STORE_SECRET_KEY
{{- end }}
{{- end }}

{{- define "agent-substrate.apiAudience" -}}
{{- if .Values.identity.apiAudience -}}
{{- .Values.identity.apiAudience -}}
{{- else -}}
{{- printf "api.%s.svc" .Release.Namespace -}}
{{- end -}}
{{- end }}

{{- define "agent-substrate.workerImage" -}}
{{- $pool := .pool -}}
{{- $root := .root -}}
{{- if $pool.workerImage -}}
{{- $pool.workerImage -}}
{{- else -}}
{{- include "agent-substrate.image" (dict "root" $root "name" "ateworker-gvisor") -}}
{{- end -}}
{{- end }}
