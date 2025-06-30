{{/*
生成Redis配置的helper函数
*/}}
{{- define "csghub.redis.config" -}}
{{- $service := .service -}}
{{- $global := .global -}}
{{- $config := dict -}}

{{- if $global.Values.global.redis.enabled -}}
  {{/* 使用内部Redis */}}
  {{- $_ := set $config "host" (include "common.names.custom" (list $global "redis")) -}}
  {{- $_ := set $config "port" 6379 -}}
  {{- $_ := set $config "password" (or $global.Values.redis.password (randAlphaNum 15)) -}}
{{- else -}}
  {{/* 使用外部Redis */}}
  {{- $_ := set $config "host" $global.Values.global.redis.host -}}
  {{- $_ := set $config "port" $global.Values.global.redis.port -}}
  {{- $_ := set $config "password" $global.Values.global.redis.password -}}
{{- end -}}

{{/* 服务级别的配置覆盖 */}}
{{- if $service.redis.host -}}
  {{- $_ := set $config "host" $service.redis.host -}}
{{- end -}}
{{- if $service.redis.port -}}
  {{- $_ := set $config "port" $service.redis.port -}}
{{- end -}}
{{- if $service.redis.password -}}
  {{- $_ := set $config "password" $service.redis.password -}}
{{- end -}}

{{/* 设置database */}}
{{- $_ := set $config "database" ($service.redis.database | default 0) -}}

{{/* 设置其他可选配置 */}}
{{- if hasKey $global.Values.global.redis "sentinel" -}}
  {{- if $global.Values.global.redis.sentinel.enabled -}}
    {{- $_ := set $config "sentinel" $global.Values.global.redis.sentinel -}}
  {{- end -}}
{{- end -}}

{{- if hasKey $global.Values.global.redis "cluster" -}}
  {{- if $global.Values.global.redis.cluster.enabled -}}
    {{- $_ := set $config "cluster" $global.Values.global.redis.cluster -}}
  {{- end -}}
{{- end -}}

{{- $config | toYaml -}}
{{- end -}}

{{/*
兼容性helper函数 - 保持原有的API
*/}}
{{- define "csghub.redis.host" -}}
{{- $config := include "csghub.redis.config" (dict "service" (dict "redis" (dict)) "global" .) | fromYaml -}}
{{- $config.host -}}
{{- end }}

{{- define "csghub.redis.port" -}}
{{- $config := include "csghub.redis.config" (dict "service" (dict "redis" (dict)) "global" .) | fromYaml -}}
{{- $config.port -}}
{{- end }}

{{- define "csghub.redis.password" -}}
{{- $config := include "csghub.redis.config" (dict "service" (dict "redis" (dict)) "global" .) | fromYaml -}}
{{- $config.password -}}
{{- end }}

{{- define "csghub.redis.endpoint" -}}
{{- printf "%s:%s" (include "csghub.redis.host" .) (include "csghub.redis.port" .) -}}
{{- end }}

{{/*
生成Redis URL
*/}}
{{- define "csghub.redis.url" -}}
{{- $service := .service -}}
{{- $global := .global -}}
{{- $config := include "csghub.redis.config" . | fromYaml -}}
{{- if $config.password -}}
redis://:{{ $config.password }}@{{ $config.host }}:{{ $config.port }}/{{ $config.database }}
{{- else -}}
redis://{{ $config.host }}:{{ $config.port }}/{{ $config.database }}
{{- end -}}
{{- end }}