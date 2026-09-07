{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Name of the Secret holding the clusterID master key.
*/}}
{{- define "common.secret.secretName" }}
  {{- include "common.names.custom" (list . "secrets") -}}
{{- end }}

{{/*
Resolve the clusterID master key (raw string, not base64).

Resolution order:
  1. stored value in the master Secret
  2. sha256 of the kube-system namespace UID (cluster fingerprint, present in
     every cluster, no extra object; requires get-namespace permission)
  3. sha256 of the current hour (offline renders or no namespace permission)
*/}}
{{- define "common.secret.masterKey" }}
  {{- $ctx := . }}
  {{- $secretName := include "common.secret.secretName" $ctx }}
  {{- $existing := lookup "v1" "Secret" $ctx.Release.Namespace $secretName }}
  {{- $stored := dig "master-key" "" (dig "data" (dict) $existing) | b64dec }}
  {{- if $stored }}
    {{- $stored -}}
  {{- else }}
    {{- $ns := lookup "v1" "Namespace" "" "kube-system" }}
    {{- $uid := dig "uid" "" (dig "metadata" (dict) $ns) }}
    {{- if $uid }}
      {{- printf "%s/%s" $uid $ctx.Release.Namespace | sha256sum -}}
    {{- else }}
      {{- printf "%s/%s" (now | date "2006010215") $ctx.Release.Namespace | sha256sum -}}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Deterministic value from the master key. The second argument is the credential
identifier (e.g. "nats.password"): same key + same context = same output, and
distinct credentials must use distinct contexts. Cross-chart shared credentials
omit the chart name prefix so subcharts agree with the parent.

sha512sum yields 128 hex, so a single derivation covers any requested length;
shorter outputs are just truncations.
*/}}
{{- define "common.secret.derive" }}
  {{- $ctx := index . 0 }}
  {{- $context := index . 1 }}
  {{- $masterKey := include "common.secret.masterKey" $ctx }}
  {{- printf "%s:%s" $masterKey $context | sha512sum -}}
{{- end }}

{{/*
Deterministic password of a given length (hex string, safe for any field).
*/}}
{{- define "common.secret.password" }}
  {{- $ctx := index . 0 }}
  {{- $context := index . 1 }}
  {{- $length := index . 2 }}
  {{- include "common.secret.derive" (list $ctx $context) | trunc (int $length) -}}
{{- end }}

{{/*
Resolve a master-key-derived credential that is persisted in the master Secret:
return the stored value (kept stable across upgrades) when present, otherwise
derive it. The context doubles as the Secret data key and the derivation seed.
*/}}
{{- define "common.secret.value" }}
  {{- $ctx := index . 0 }}
  {{- $context := index . 1 }}
  {{- $length := index . 2 }}
  {{- $secretName := include "common.secret.secretName" $ctx }}
  {{- $existing := lookup "v1" "Secret" $ctx.Release.Namespace $secretName }}
  {{- $stored := dig $context "" (dig "data" (dict) $existing) | b64dec }}
  {{- if $stored }}
    {{- $stored -}}
  {{- else }}
    {{- include "common.secret.password" (list $ctx $context $length) -}}
  {{- end }}
{{- end }}
