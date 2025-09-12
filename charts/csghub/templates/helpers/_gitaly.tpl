{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
generate gitaly config
*/}}
{{- define "csghub.gitaly.config" -}}
{{- $service := .service -}}
{{- $global := .global -}}
{{- $config := dict -}}

{{- if $global.Values.global.gitaly.enabled -}}
  {{/* use internal gitaly */}}
  {{- $_ := set $config "host" (include "common.names.custom" (list $global "gitaly")) -}}
  {{- $_ := set $config "port" (or $global.Values.gitaly.port (include "gitaly.internal.port" $global)) -}}
  {{- $_ := set $config "storage" ($global.Values.gitaly.storage | default "default") -}}
  {{- $_ := set $config "token" (or $global.Values.gitaly.token (include "gitaly.internal.token" $global)) -}}
  {{- $_ := set $config "isCluster" false -}}
  {{- $_ := set $config "scheme" "tcp" -}}
{{- else -}}
  {{/* use external gitaly */}}
  {{- $_ := set $config "host" $global.Values.global.gitaly.external.host -}}
  {{- $_ := set $config "port" $global.Values.global.gitaly.external.port -}}
  {{- $_ := set $config "storage" ($global.Values.global.gitaly.external.storage | default "default") -}}
  {{- $_ := set $config "token" $global.Values.global.gitaly.external.token -}}
  {{- $_ := set $config "isCluster" ($global.Values.global.gitaly.external.isCluster | default false) -}}
  {{- $_ := set $config "scheme" ($global.Values.global.gitaly.external.scheme | default "tcp") -}}
{{- end -}}

{{/* ensure port is string */}}
{{- $_ := set $config "port" ($config.port | toString) -}}

{{- $config | toYaml -}}
{{- end -}}

{{/*
generate gitaly grpc endpoint
*/}}
{{- define "csghub.gitaly.grpcEndpoint" -}}
{{- $service := .service -}}
{{- $global := .global -}}
{{- $config := include "csghub.gitaly.config" . | fromYaml -}}
{{- printf "%s://%s:%s" $config.scheme $config.host $config.port -}}
{{- end }}
