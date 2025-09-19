{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate Mongo Connection Configuration
*/}}
{{- define "csghub.mongo.config" -}}
{{- $service := .service -}}
{{- $global := .global -}}

{{- /* Configuration priority: internal Mongo (if enabled) > service-level external > global external */ -}}

{{- /* Default configuration for internal Mongo */ -}}
{{- $mongoName := include "common.names.custom" (list $global "mongo") -}}
{{- $user := "root" -}}
{{- $password := include "common.randomPassword" "mongo" -}}
{{- if $service.mongo -}}
  {{- with $service.mongo.auth -}}
    {{- $user = .user | default "root" -}}
    {{- $password = .password | default (include "common.randomPassword" "mongo") -}}
  {{- end -}}
{{- end -}}

{{- $mongoConfig := dict
  "host" $mongoName
  "port" (include "csghub.svc.port" "mongo")
  "user" $user
  "password" $password
-}}

{{- /* If internal Mongo is enabled and secret exists, use existing password */ -}}
{{- if $global.Values.global.mongo.enabled -}}
  {{- $secret := (lookup "v1" "Secret" $global.Release.Namespace $mongoName) -}}
  {{- if and $secret $secret.data.MONGO_INITDB_ROOT_USERNAME -}}
    {{- $_ := set $mongoConfig "password" ($secret.data.MONGO_INITDB_ROOT_USERNAME | b64dec) -}}
  {{- end -}}
  {{- if and $secret $secret.data.MONGO_INITDB_ROOT_PASSWORD -}}
    {{- $_ := set $mongoConfig "password" ($secret.data.MONGO_INITDB_ROOT_PASSWORD | b64dec) -}}
  {{- end -}}
{{- end -}}

{{- /* Override with external Mongo configuration if internal is disabled */ -}}
{{- if not $global.Values.global.mongo.enabled -}}
  {{- /* Global external Mongo configuration */ -}}
  {{- with $global.Values.global.mongo.external -}}
    {{- $mongoConfig = merge $mongoConfig (dict
      "host" (.host | default $mongoConfig.host)
      "port" (.port | default $mongoConfig.port)
      "user" (.user | default $mongoConfig.user)
      "password" (.password | default $mongoConfig.password)
    ) -}}
  {{- end -}}

  {{- /* Service-level external Mongo configuration (higher priority) */ -}}
  {{- with $service.mongo -}}
    {{- $mongoConfig = merge $mongoConfig (dict
      "host" (.host | default $mongoConfig.host)
      "port" (.port | default $mongoConfig.port)
      "user" (.user | default $mongoConfig.user)
      "password" (.password | default $mongoConfig.password)
    ) -}}
  {{- end -}}
{{- end -}}

{{- if not $mongoConfig.user -}}
  {{- fail "Mongo user must be set" -}}
{{- end -}}

{{- /* Validate required configurations */ -}}
{{- if not $mongoConfig.password -}}
  {{- fail "Mongo password must be set" -}}
{{- end -}}

{{- $mongoConfig | toYaml -}}
{{- end -}}