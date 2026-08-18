{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Internal: compute the merging namespace mode by walking the standalone
and umbrella value paths. Returns "" when no mergingNamespace is set.
Not intended for direct caller use — see the public namespace.* helpers
below. Both modes honour the precedence:
  .Values.runner.runner.mergingNamespace (umbrella parent)
  > .Values.runner.mergingNamespace (standalone runner)
  > .Values.mergingNamespace (chart-level)
*/}}
{{- define "common.namespace._merging" }}
{{- $runner := .Values.runner | default dict }}
{{- $runnerConfig := $runner.runner | default dict }}
{{- $merging := "" }}
{{- if hasKey $runner "mergingNamespace" }}
  {{- $merging = $runner.mergingNamespace }}
{{- else if hasKey $runnerConfig "mergingNamespace" }}
  {{- $merging = $runnerConfig.mergingNamespace }}
{{- else if hasKey .Values "mergingNamespace" }}
  {{- $merging = .Values.mergingNamespace }}
{{- end }}
{{- $merging -}}
{{- end }}

{{/*
Internal: resolve a controller's namespace from the merging mode plus
per-controller defaults. Callers pass:
  ctx:     Helm root context (.)
  multi:   namespace to use when merging == "multi"
  default: namespace to use otherwise (i.e. merging == "" or other)
*/}}
{{- define "common.namespace._resolve" }}
{{- $merging := include "common.namespace._merging" .ctx }}
{{- if eq $merging "single" }}
  {{- .ctx.Release.Namespace }}
{{- else if eq $merging "multi" }}
  {{- .multi }}
{{- else }}
  {{- .default }}
{{- end }}
{{- end }}

{{/*
Return Argo Namespace.
*/}}
{{- define "namespace.argo" }}
{{- include "common.namespace._resolve" (dict "ctx" . "multi" "" "default" "argo") -}}
{{- end }}

{{/*
Return Knative Namespace.
*/}}
{{- define "namespace.knative" }}
{{- include "common.namespace._resolve" (dict "ctx" . "multi" "" "default" "knative-serving") -}}
{{- end }}

{{/*
Return Kourier Namespace.
*/}}
{{- define "namespace.kourier" }}
{{- include "common.namespace._resolve" (dict "ctx" . "multi" "knative-serving" "default" "kourier-system") -}}
{{- end }}

{{/*
Return LeaderWorkset (LWS) Namespace.
*/}}
{{- define "namespace.lws" }}
{{- include "common.namespace._resolve" (dict "ctx" . "multi" "" "default" "lws-system") -}}
{{- end }}

{{/*
Return Space Namespace.

Unlike the other helpers, spaces honours an explicit per-value namespace
override (runner.namespace / runner.runner.namespace / chart-level
namespace) when merging != "single". Falls back to "" when no override
is set so the caller can decide whether to default to Release.Namespace.
*/}}
{{- define "namespace.spaces" }}
{{- $merging := include "common.namespace._merging" . }}
{{- $ns := "" }}
{{- if eq $merging "single" }}
  {{- $ns = .Release.Namespace }}
{{- else }}
  {{- $runner := .Values.runner | default dict }}
  {{- $runnerConfig := $runner.runner | default dict }}
  {{- if hasKey $runner "namespace" }}
    {{- $ns = $runner.namespace }}
  {{- else if hasKey $runnerConfig "namespace" }}
    {{- $ns = $runnerConfig.namespace }}
  {{- else if hasKey .Values "namespace" }}
    {{- $ns = .Values.namespace }}
  {{- end }}
{{- end }}
{{- $ns -}}
{{- end }}