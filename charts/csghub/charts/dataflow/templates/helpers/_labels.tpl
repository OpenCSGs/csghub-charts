{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Kubernetes standard labels
*/}}
{{- define "common.labels" -}}
{{- $ctx := . }}
{{- $customLabels := dict -}}
{{- $service := "" -}}
{{- $selectorOnly := false -}}


{{- /* parse arguments */ -}}
{{- if hasKey . "context" -}}
  {{- $ctx = .context -}}
  {{- $customLabels = .customLabels | default dict -}}
  {{- $service = .service | default "" -}}
  {{- $selectorOnly = .selector | default false -}}
{{- end -}}

{{- /* base labels */ -}}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}

{{- if $service }}
app.kubernetes.io/name: {{ $service }}
{{- else }}
app.kubernetes.io/name: {{ include "common.names.name" $ctx }}
{{- end }}

{{- if not $selectorOnly }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service }}
helm.sh/chart: {{ include "common.names.chart" $ctx }}
{{- with $ctx.Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end }}

{{- /* custom labels */ -}}
{{- range $key, $value := $customLabels }}
{{ $key }}: {{ $value | quote }}
{{- end -}}
{{- end -}}

{{- /*
Selector labels
*/}}
{{- define "common.labels.selector" -}}
{{ include "common.labels" (dict "selector" true "context" .) }}
{{- end -}}

{{- /*
Service Selector labels
*/}}
{{- define "common.serviceSelectorLabels" -}}
{{ include "common.labels" (dict "selector" true "service" .service "context" .context) }}
{{- end -}}

{{- /*
Define matched labels for network policies
*/}}
{{- define "common.labels.selector.netpol" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}