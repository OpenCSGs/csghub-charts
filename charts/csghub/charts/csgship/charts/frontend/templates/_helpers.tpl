{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for frontend
*/}}
{{- define "frontend.internal.domain" -}}
{{- include "common.names.custom" (list . "frontend") }}
{{- end }}

{{/*
Define the internal port for frontend
*/}}
{{- define "frontend.internal.port" -}}
{{- $port := "80" }}
{{- if hasKey .Values.global "frontend" }}
  {{- if hasKey .Values.global.frontend "service" }}
    {{- if hasKey .Values.global.frontend.service "port" }}
      {{- $port = .Values.global.frontend.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}
