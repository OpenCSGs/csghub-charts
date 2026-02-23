{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "common.names.name" }}
  {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "common.names.chart" }}
  {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "common.names.fullname" }}
  {{- if .Values.fullnameOverride }}
    {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
  {{- else }}
    {{- $name := default .Chart.Name .Values.nameOverride }}
    {{- if contains $name .Release.Name }}
      {{- .Release.Name | trunc 63 | trimSuffix "-" -}}
    {{- else }}
      {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Create a custom name with flexible formatting options.

Usage:
1. Single context: {{ include "common.names.custom" . }}
   - Returns: <release-name>-<chart-name>

2. Context with override: {{ include "common.names.custom" (list . "custom-component") }}
   - Returns: <release-name>-<custom-component>

The name will be truncated to 63 characters to comply with Kubernetes DNS naming specifications.
*/}}
{{- define "common.names.custom" }}
  {{- if eq (kindOf .) "slice" }}
    {{- /* Handle slice input (context with optional override) */}}
    {{- if gt (len .) 0 }}
      {{- $ctx := index . 0 }}
      {{- $defaultName := printf "%s-%s" $ctx.Release.Name $ctx.Chart.Name -}}
      {{- if gt (len .) 1 }}
        {{- /* Use override name if provided */}}
        {{- $overrideName := printf "%s-%s" $ctx.Release.Name (index . 1) }}
        {{- $overrideName | trunc 63 | trimSuffix "-" -}}
      {{- else }}
        {{- /* Use default chart name */}}
        {{- $defaultName | trunc 63 | trimSuffix "-" -}}
      {{- end }}
    {{- else }}
      {{ fail "No context provided to common.names.custom template" }}
    {{- end }}
  {{- else }}
    {{- /* Handle single context input */}}
    {{ $defaultName := printf "%s-%s" .Release.Name .Chart.Name }}
    {{- $defaultName | trunc 63 | trimSuffix "-" -}}
  {{- end }}
{{- end -}}