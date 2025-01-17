{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for gitlab-shell
*/}}
{{- define "gitlab-shell.internal.domain" -}}
{{- include "common.names.custom" (list . "gitlab-shell") }}
{{- end }}

{{/*
Define the internal port for gitlab-shell
*/}}
{{- define "gitlab-shell.internal.port" -}}
{{- $port := "22" }}
{{- if hasKey .Values.global "gitlabShell" }}
  {{- if hasKey .Values.global.gitlabShell "service" }}
    {{- if hasKey .Values.global.gitlabShell.service "port" }}
      {{- $port = .Values.global.gitlabShell.service.port | toString }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port -}}
{{- end }}

{{/*
Define the internal endpoint for gitlab-shell
*/}}
{{- define "gitlab-shell.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "gitlab-shell.internal.domain" .) (include "gitlab-shell.internal.port" .) }}
{{- end }}

{{/*
Define the external port for gitlab-shell
*/}}
{{- define "gitlab-shell.external.port" -}}
{{- if eq .Values.global.ingress.service.type "NodePort" }}
{{- "30022" | toString }}
{{- else }}
{{- "22" | toString }}
{{- end }}
{{- end }}
