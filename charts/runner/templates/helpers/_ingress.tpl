{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Define if Ingress TLS enabled
*/}}
{{- define "global.ingress.tls.enabled" -}}
{{- $enabled := false }}
{{- if hasKey .Values.global.ingress "tls" }}
  {{- if hasKey .Values.global.ingress.tls "enabled" }}
    {{- $enabled = .Values.global.ingress.tls.enabled }}
  {{- end }}
{{- end }}
{{- $enabled  }}
{{- end }}

{{/*
Define if Ingress TLS secret
*/}}
{{- define "global.ingress.tls.secret" -}}
{{- $secret := "" }}
{{- if hasKey .Values.global.ingress "tls" }}
  {{- if hasKey .Values.global.ingress.tls "secretName" }}
    {{- if .Values.global.ingress.tls.secretName }}
        {{- $secret = .Values.global.ingress.tls.secretName }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $secret }}
{{- end }}