{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for web
*/}}
{{- define "web.internal.domain" -}}
{{- include "common.names.custom" (list . "web") }}
{{- end }}

{{/*
Define the internal port for web
*/}}
{{- define "web.internal.port" -}}
{{- $port := "8000" }}
{{- if hasKey .Values.global "web" }}
  {{- if hasKey .Values.global.web "service" }}
    {{- if hasKey .Values.global.web.service "port" }}
      {{- $port = .Values.global.web.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for web
*/}}
{{- define "web.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "web.internal.domain" .) (include "web.internal.port" .) -}}
{{- end }}
