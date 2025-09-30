{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Return Space Namespace.
*/}}
{{- define "namespace.spaces" }}
{{- if eq .Values.runner.mergingNamespace "single" }}
  {{- .Release.Namespace -}}
{{- else }}
  {{- .Values.runner.namespace -}}
{{- end }}
{{- end }}

{{/*
Return argo Namespace.
*/}}
{{- define "namespace.argo" }}
{{- if eq .Values.runner.mergingNamespace "single" }}
  {{- .Release.Namespace -}}
{{- else }}
  {{- "argo" -}}
{{- end }}
{{- end }}

{{/*
Return knative Namespace.
*/}}
{{- define "namespace.knative" }}
{{- if eq .Values.runner.mergingNamespace "single" }}
  {{- .Release.Namespace -}}
{{- else }}
  {{- "knative-serving" -}}
{{- end }}
{{- end }}

{{/*
Return kourier Namespace.
*/}}
{{- define "namespace.kourier" }}
{{- if eq .Values.runner.mergingNamespace "single" }}
  {{- .Release.Namespace -}}
{{- else if eq .Values.runner.mergingNamespace "multi" }}
  {{- "knative-serving" -}}
{{- else }}
  {{- "kourier-system" -}}
{{- end }}
{{- end }}

{{/*
Return leaderworkset Namespace.
*/}}
{{- define "namespace.lws" }}
{{- if eq .Values.runner.mergingNamespace "single" }}
  {{- .Release.Namespace -}}
{{- else }}
  {{- "lws-system" -}}
{{- end }}
{{- end }}
