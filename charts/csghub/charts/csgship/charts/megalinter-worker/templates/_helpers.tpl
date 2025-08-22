{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for megalinter-worker
*/}}
{{- define "megalinter-worker.internal.domain" -}}
{{- include "common.names.custom" (list . "megalinter-worker") }}
{{- end }}

{{/*
Define the internal port for megalinter-worker
*/}}
{{- define "megalinter-worker.internal.port" -}}
{{- $port := "8000" }}
{{- if hasKey .Values.global "megalinterWorker" }}
  {{- if hasKey .Values.global.megalinterWorker "service" }}
    {{- if hasKey .Values.global.megalinterWorker.service "port" }}
      {{- $port = .Values.global.megalinterWorker.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for megalinter-worker
*/}}
{{- define "megalinter-worker.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "megalinter-worker.internal.domain" .) (include "megalinter-worker.internal.port" .) -}}
{{- end }}