{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for billing
*/}}
{{- define "billing.internal.domain" -}}
{{- include "common.names.custom" (list . "billing") }}
{{- end }}

{{/*
Define the internal port for billing
*/}}
{{- define "billing.internal.port" -}}
{{- $port := "8080" }}
{{- if hasKey .Values.global "billing" }}
  {{- if hasKey .Values.global.billing "service" }}
    {{- if hasKey .Values.global.billing.service "port" }}
      {{- $port = .Values.global.billing.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for billing
*/}}
{{- define "billing.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "billing.internal.domain" .) (include "billing.internal.port" .) -}}
{{- end }}