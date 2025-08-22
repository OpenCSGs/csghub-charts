{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for agentic
*/}}
{{- define "agentic.internal.domain" -}}
{{- include "common.names.custom" (list . "agentic") }}
{{- end }}

{{/*
Define the internal port for agentic
*/}}
{{- define "agentic.internal.port" -}}
{{- $port := "8000" }}
{{- if hasKey .Values.global "agentic" }}
  {{- if hasKey .Values.global.agentic "service" }}
    {{- if hasKey .Values.global.agentic.service "port" }}
      {{- $port = .Values.global.agentic.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for agentic
*/}}
{{- define "agentic.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "agentic.internal.domain" .) (include "agentic.internal.port" .) -}}
{{- end }}
