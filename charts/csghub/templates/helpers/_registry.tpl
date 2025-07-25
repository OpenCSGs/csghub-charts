{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
generate registry config
*/}}
{{- define "chart.registryConfig" -}}
{{- $service := .service -}}
{{- $global := .global -}}
{{- $config := dict -}}

{{- if $global.Values.global.registry.enabled -}}
  {{/* use internal registry */}}
  {{- $_ := set $config "registry" (include "registry.external.endpoint" $global) -}}
  {{- $_ := set $config "repository" $global.Release.Name -}}

  {{/* default credentials */}}
  {{- $defaultUser := $global.Values.registry.username }}
  {{- $defaultPass := (include "registry.initPass" $global.Release.Name) }}
  {{- $defaultHtpasswd := htpasswd ($defaultUser | toString) $defaultPass }}
  {{- $_ := set $config "username" $defaultUser -}}
  {{- $_ := set $config "password" $defaultPass -}}
  {{- $_ := set $config "htpasswd" $defaultHtpasswd -}}

  {{/* use secrets if exists */}}
  {{- $secret := (include "common.names.custom" (list $global "registry")) -}}
  {{- $secretData := (lookup "v1" "Secret" $global.Release.Namespace $secret).data }}
  {{- if $secretData }}
  {{- $secretUser := index $secretData "REGISTRY_USERNAME" }}
  {{- if $secretUser }}
  {{- $_ := set $config "username" ($secretUser | b64dec) -}}
  {{- end }}
  {{- $secretPass := index $secretData "REGISTRY_PASSWORD" }}
  {{- if $secretPass }}
  {{- $_ := set $config "password" ($secretPass | b64dec) -}}
  {{- end }}
  {{- $secretHtpasswd := index $secretData "htpasswd" }}
  {{- if $secretHtpasswd }}
  {{- $_ := set $config "htpasswd" ($secretHtpasswd | b64dec) -}}
  {{- end }}
  {{- end }}

{{- else -}}
  {{/* use external registry */}}
  {{- $_ := set $config "registry" $global.Values.registry.registry -}}
  {{- $_ := set $config "repository" $global.Values.registry.repository -}}
  {{- $_ := set $config "username" $global.Values.registry.username -}}
  {{- $_ := set $config "password" $global.Values.registry.password -}}
{{- end -}}

{{/* service level config override */}}
{{- if $service.registry.registry -}}
  {{- $_ := set $config "registry" $service.registry.registry -}}
{{- end -}}
{{- if $service.registry.repository -}}
  {{- $_ := set $config "repository" $service.registry.repository -}}
{{- end -}}
{{- if $service.registry.username -}}
  {{- $_ := set $config "username" $service.registry.username -}}
{{- end -}}
{{- if $service.registry.password -}}
  {{- $_ := set $config "password" $service.registry.password -}}
{{- end -}}

{{- $config | toYaml -}}
{{- end -}}