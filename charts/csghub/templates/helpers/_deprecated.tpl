{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{ define "common.checkDeprecated" }}

{{- if hasKey .Values.global "dataflow" }}
{{- if hasKey .Values.global.dataflow "enabled" }}
{{ fail "ERROR: 'global.dataflow.enabled' is deprecated. Rollback to 'dataflow.enabled'." }}
{{- end }}
{{- end }}

{{- if hasKey .Values.global "deployment" }}
{{ fail "ERROR: 'global.deployment' is deprecated. Please use 'global.<key>' instead." }}
{{- end }}

{{- end }}