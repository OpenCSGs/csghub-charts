{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Return service dict with ensured name
Usage:
  {{ $mirrorSvc := include "common.service" (dict "service" "mirror" "global" .) | fromYaml }}
*/}}
{{- define "common.service" -}}
{{- $global := .global -}}
{{- $serviceType := .service -}}
{{- $svc := index $global.Values $serviceType | default dict -}}
{{- $name := dig "name" (kebabcase $serviceType) $svc -}}
{{- mergeOverwrite (dict "name" $name) $svc | toYaml -}}
{{- end -}}