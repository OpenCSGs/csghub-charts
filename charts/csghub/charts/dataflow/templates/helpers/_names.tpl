{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "common.names.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "common.names.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "common.names.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "common.names.custom" -}}
{{- /*
  Create a name with the format <release-name>-<chart-name> if the input is a single context.
  Create a name with the format <release-name>-<override-name> if the input is a list of two elements.
  The first element is the context.
  The second element is the override name.
  The name will be truncated to 63 characters.
*/}}
{{- if eq (kindOf .) "slice" -}}
  {{- if gt (len .) 0 -}}
    {{- $context := index . 0 -}}
    {{- $defaultName := printf "%s-%s" $context.Release.Name $context.Chart.Name -}}
    {{- if gt (len .) 1 -}}
      {{- $overrideName := printf "%s-%s" $context.Release.Name (index . 1) -}}
      {{- $overrideName | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
      {{- $defaultName | trunc 63 | trimSuffix "-" -}}
    {{- end -}}
  {{- else -}}
    {{- "Error: No context provided" -}}
  {{- end -}}
{{- else -}}
  {{- $defaultName := printf "%s-%s" .Release.Name .Chart.Name -}}
  {{- $defaultName | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}


