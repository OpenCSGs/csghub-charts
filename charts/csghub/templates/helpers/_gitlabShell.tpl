{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the external port for gitlab-shell
*/}}
{{- define "gitlab-shell.external.port" -}}
{{- $sshPort := .Values.csghub.server.gitlabShell.sshPort | default "22" }}
{{- if eq .Values.global.ingress.service.type "NodePort" }}
{{- $sshPort = "30022" }}
{{- end }}
{{- $sshPort | toString }}
{{- end }}
