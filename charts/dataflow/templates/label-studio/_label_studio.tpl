{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# Label Studio Domain Helper
# Generates the full domain name for Label Studio service based on configuration
# Usage: {{ include "common.domain.labelstudio" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.labelstudio" }}
{{- $service := include "common.service" (dict "ctx" . "service" "labelStudio") | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# Label Studio External Endpoint Helper
# Generates the complete external access endpoint for Label Studio service
# Usage: {{ include "common.endpoint.labelstudio" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.labelstudio" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.labelstudio" .)) -}}
{{- end }}