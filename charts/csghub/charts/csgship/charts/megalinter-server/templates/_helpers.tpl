{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for megalinter-server
*/}}
{{- define "megalinter-server.internal.domain" -}}
{{- include "common.names.custom" (list . "megalinter-server") }}
{{- end }}

{{/*
Define the internal port for megalinter-server
*/}}
{{- define "megalinter-server.internal.port" -}}
{{- $port := "8000" }}
{{- if hasKey .Values.global "megalinterServer" }}
  {{- if hasKey .Values.global.megalinterServer "service" }}
    {{- if hasKey .Values.global.megalinterServer.service "port" }}
      {{- $port = .Values.global.megalinterServer.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for megalinter-server
*/}}
{{- define "megalinter-server.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "megalinter-server.internal.domain" .) (include "megalinter-server.internal.port" .) -}}
{{- end }}