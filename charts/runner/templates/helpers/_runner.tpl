{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define the internal domain for csghub
*/}}
{{- define "runner.internal.domain" -}}
{{- include "common.names.custom" (list . "runner") }}
{{- end }}

{{/*
Define the internal port for csghub
*/}}
{{- define "runner.internal.port" -}}
{{- $port := include "csghub.svc.port" "runner" }}
{{- if hasKey .Values.global "runner" }}
  {{- if hasKey .Values.global.runner "service" }}
    {{- if hasKey .Values.global.runner.service "port" }}
      {{- $port = .Values.global.runner.service.port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $port | toString -}}
{{- end }}

{{/*
Define the internal endpoint for csghub
*/}}
{{- define "runner.internal.endpoint" -}}
{{- printf "http://%s:%s" (include "runner.internal.domain" .) (include "runner.internal.port" .) -}}
{{- end }}

{{/*
Define the external domain for runner
*/}}
{{- define "runner.external.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.runner "runner")) }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for csghub
*/}}
{{- define "runner.external.endpoint" -}}
{{- $domain := include "runner.external.domain" . }}
{{- if eq .Values.global.ingress.service.type "NodePort" }}
{{- if .Values.global.ingress.tls.enabled -}}
{{- printf "https://%s:%s" $domain "30443" -}}
{{- else }}
{{- printf "http://%s:%s" $domain "30080" -}}
{{- end }}
{{- else }}
{{- if .Values.global.ingress.tls.enabled -}}
{{- printf "https://%s" $domain -}}
{{- else }}
{{- printf "http://%s" $domain -}}
{{- end }}
{{- end }}
{{- end }}

{{/*
Define the external domain for runner
*/}}
{{- define "runner.external.public.domain" -}}
{{- $domain := include "global.domain" (list . (or .Values.global.ingress.customDomainPrefixes.public "public")) }}
{{- $domain -}}
{{- end }}

{{/*
Define the external endpoint for csghub
*/}}
{{- define "runner.external.public.endpoint" -}}
{{- $domain := include "runner.external.public.domain" . }}
{{- if eq .Values.global.ingress.service.type "NodePort" }}
{{- if .Values.global.ingress.tls.enabled -}}
{{- printf "https://%s:%s" $domain "30443" -}}
{{- else }}
{{- printf "http://%s:%s" $domain "30080" -}}
{{- end }}
{{- else }}
{{- if .Values.global.ingress.tls.enabled -}}
{{- printf "https://%s" $domain -}}
{{- else }}
{{- printf "http://%s" $domain -}}
{{- end }}
{{- end }}
{{- end }}

{{/*
Define the kaniko args for runner
*/}}
{{- define "runner.kaniko.args" -}}
{{- $speedUpArgs := "--compressed-caching=false,--single-snapshot,--log-format=text" }}
{{- $pypi := printf "--build-arg=PyPI=%s" .Values.global.pipIndexUrl }}
{{- $hf := printf "--build-arg=HF_ENDPOINT=%s/hf" (or .Values.externalUrl (include "csghub.external.endpoint" .)) }}
{{- $insecure := "" }}
{{- if or .Values.global.registry.enabled .Values.registry.insecure .Values.global.registry.external.insecure }}
{{- $insecure = "--skip-tls-verify,--skip-tls-verify-pull,--insecure,--insecure-pull" }}
{{- end }}
{{- printf "%s,%s,%s,%s" $speedUpArgs $pypi $hf $insecure | trimSuffix "," -}}
{{- end }}