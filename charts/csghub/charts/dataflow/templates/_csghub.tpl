{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# csghub Domain Helper
# Generates the full domain name for csghub service based on configuration
# Usage: {{ include "common.domain.csghub" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.csghub" -}}
{{- $sub := .Release.Name }}
{{- if .Values.global.ingress.useTop }}
{{- $sub = "" }}
{{- end }}
{{- include "common.domain" (dict "ctx" . "sub" $sub) -}}
{{- end }}

{{/*
# csghub Public Domain Helper
# Generates the full domain name for csghub service based on configuration
# Usage: {{ include "common.domain.public" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.public" -}}
{{- $sub := "public" }}
{{- if .Values.global.ingress.useTop }}
{{- $sub = "" }}
{{- end }}
{{- include "common.domain" (dict "ctx" . "sub" $sub) -}}
{{- end }}

{{/*
# csghub External Endpoint Helper
# Generates the complete external access endpoint for csghub service
# Usage: {{ include "common.endpoint.csghub" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.csghub" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.csghub" .)) -}}
{{- end }}