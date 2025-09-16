{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Return Spaces Namespace.
*/}}
{{- define "namespace.spaces" }}
{{- .Values.global.namespace | default "spaces" -}}
{{- end }}

{{/*
Return argo Namespace.
*/}}
{{- define "namespace.argo" }}
{{- $argoNamespace := "argo" }}
{{- if eq .Values.global.mergingNamespace "Single" }}
  {{- $argoNamespace = .Release.Namespace }}
{{- end }}
{{- $argoNamespace -}}
{{- end }}

{{/*
Return knative Namespace.
*/}}
{{- define "namespace.knative" }}
{{- $knativeNamespace := "knative-serving" }}
{{- if eq .Values.global.mergingNamespace "Single" }}
  {{- $knativeNamespace = .Release.Namespace }}
{{- end }}
{{- $knativeNamespace -}}
{{- end }}

{{/*
Return kourier Namespace.
*/}}
{{- define "namespace.kourier" }}
{{- $kourierNamespace := "kourier-system" }}
{{- if eq .Values.global.mergingNamespace "Multi" }}
  {{- $kourierNamespace = include "namespace.knative" . }}
{{- else if eq .Values.global.mergingNamespace "Single" }}
  {{- $kourierNamespace = .Release.Namespace }}
{{- end }}
{{- $kourierNamespace -}}
{{- end }}

{{/*
Return leaderworkset Namespace.
*/}}
{{- define "namespace.lws" }}
{{- $lwsNamespace := "lws-system" }}
{{- if eq .Values.global.mergingNamespace "Single" }}
  {{- $lwsNamespace = .Release.Namespace }}
{{- end }}
{{- $lwsNamespace -}}
{{- end }}
