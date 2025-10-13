{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Return Space Namespace.
*/}}
{{- define "namespace.spaces" -}}
{{- $ns := "" -}}

{{- $runner := .Values.runner | default dict -}}
{{- $merging := "" -}}

{{- if hasKey $runner "mergingNamespace" -}}
  {{- $merging = $runner.mergingNamespace -}}
{{- else if hasKey .Values "mergingNamespace" -}}
  {{- $merging = .Values.mergingNamespace -}}
{{- end -}}

{{- if eq $merging "single" -}}
  {{- $ns = .Release.Namespace -}}
{{- else if hasKey $runner "namespace" -}}
  {{- $ns = $runner.namespace -}}
{{- else if hasKey .Values "namespace" -}}
  {{- $ns = .Values.namespace -}}
{{- end -}}

{{- $ns -}}
{{- end }}

{{/*
Return Argo Namespace.
*/}}
{{- define "namespace.argo" -}}
{{- $ns := "" -}}
{{- $runner := .Values.runner | default dict -}}
{{- $merging := "" -}}

{{- if hasKey $runner "mergingNamespace" -}}
  {{- $merging = $runner.mergingNamespace -}}
{{- else if hasKey .Values "mergingNamespace" -}}
  {{- $merging = .Values.mergingNamespace -}}
{{- end -}}

{{- if eq $merging "single" -}}
  {{- $ns = .Release.Namespace -}}
{{- else -}}
  {{- $ns = "argo" -}}
{{- end -}}

{{- $ns -}}
{{- end }}


{{/*
Return Knative Namespace.
*/}}
{{- define "namespace.knative" -}}
{{- $ns := "" -}}
{{- $runner := .Values.runner | default dict -}}
{{- $merging := "" -}}

{{- if hasKey $runner "mergingNamespace" -}}
  {{- $merging = $runner.mergingNamespace -}}
{{- else if hasKey .Values "mergingNamespace" -}}
  {{- $merging = .Values.mergingNamespace -}}
{{- end -}}

{{- if eq $merging "single" -}}
  {{- $ns = .Release.Namespace -}}
{{- else -}}
  {{- $ns = "knative-serving" -}}
{{- end -}}

{{- $ns -}}
{{- end }}


{{/*
Return Kourier Namespace.
*/}}
{{- define "namespace.kourier" -}}
{{- $ns := "" -}}
{{- $runner := .Values.runner | default dict -}}
{{- $merging := "" -}}

{{- if hasKey $runner "mergingNamespace" -}}
  {{- $merging = $runner.mergingNamespace -}}
{{- else if hasKey .Values "mergingNamespace" -}}
  {{- $merging = .Values.mergingNamespace -}}
{{- end -}}

{{- if eq $merging "single" -}}
  {{- $ns = .Release.Namespace -}}
{{- else if eq $merging "multi" -}}
  {{- $ns = "knative-serving" -}}
{{- else -}}
  {{- $ns = "kourier-system" -}}
{{- end -}}

{{- $ns -}}
{{- end }}


{{/*
Return LeaderWorkset (LWS) Namespace.
*/}}
{{- define "namespace.lws" -}}
{{- $ns := "" -}}
{{- $runner := .Values.runner | default dict -}}
{{- $merging := "" -}}

{{- if hasKey $runner "mergingNamespace" -}}
  {{- $merging = $runner.mergingNamespace -}}
{{- else if hasKey .Values "mergingNamespace" -}}
  {{- $merging = .Values.mergingNamespace -}}
{{- end -}}

{{- if eq $merging "single" -}}
  {{- $ns = .Release.Namespace -}}
{{- else -}}
  {{- $ns = "lws-system" -}}
{{- end -}}

{{- $ns -}}
{{- end }}