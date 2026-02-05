{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Kubernetes standard labels template with flexible configuration options.

Usage examples:
1. Basic usage: {{ include "common.labels" . }}
2. With service name: {{ include "common.labels" (dict "ctx" . "service" "my-service") }}
3. Selector only: {{ include "common.labels" (dict "ctx" . "selector" true) }}
4. With custom labels: {{ include "common.labels" (dict "ctx" . "customLabels" (dict "env" "prod")) }}
5. Combined options: {{ include "common.labels" (dict "ctx" . "service" "api" "selector" true "customLabels" (dict "tier" "backend")) }}
*/}}
{{- define "common.labels" }}
  {{- /* Initialize parameters with defaults */}}
  {{- $ctx := . }}
  {{- $customLabels := dict }}
  {{- $service := "" }}
  {{- $selectorOnly := false }}

  {{- /* Parse input arguments - support both direct context and dict format */}}
  {{- if kindIs "map" . }}
    {{- if hasKey . "ctx" }}
      {{- $ctx = .ctx }}
      {{- $customLabels = .customLabels | default dict }}
      {{- $service = .service | default "" }}
      {{- $selectorOnly = .selector | default false }}
    {{- end }}
  {{- end }}

  {{- /* Core Kubernetes labels - no indentation for YAML output */}}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}
  {{- if $service }}
app.kubernetes.io/name: {{ $service }}
  {{- else }}
app.kubernetes.io/name: {{ include "common.names.name" $ctx }}
  {{- end }}
  {{- if not $selectorOnly }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service }}
  {{- end }}

  {{- /* User-defined custom labels */}}
  {{- range $key, $value := $customLabels }}
{{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}

{{/*
Selector labels - includes only the minimal labels needed for pod selection.
Perfect for use in Deployment, StatefulSet, and DaemonSet selectors.

Usage: {{ include "common.labels.selector" . }}
*/}}
{{- define "common.labels.selector" }}
  {{- include "common.labels" (dict "ctx" . "selector" true) -}}
{{- end }}

{{/*
Service-specific selector labels with custom service name.
Ideal for Service resource selectors when you need to override the default app name.

Usage: {{ include "common.serviceSelectorLabels" (dict "ctx" . "service" "my-service") }}
*/}}
{{- define "common.serviceSelectorLabels" }}
  {{- include "common.labels" (dict "ctx" .ctx "selector" true "service" .service) -}}
{{- end }}

{{/*
Minimal selector labels for network policies.
Provides the most basic label matching for network policy rules to avoid over-selection.

Usage: {{ include "common.labels.selector.netpol" . }}
*/}}
{{- define "common.labels.selector.netpol" }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Complete labels including all metadata labels.
Use this when you need all available labels (e.g., for Prometheus monitoring).

Usage: {{ include "common.labels.complete" . }}
*/}}
{{- define "common.labels.complete" }}
  {{- include "common.labels" (dict "ctx" . "selector" false) -}}
{{- end }}