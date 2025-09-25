{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Generate Nats Configuration
*/}}
{{- define "nats.config"}}

{{/* default config for initialization */}}
{{- $host := include "nats.internal.domain" . }}
{{- $port := include "nats.internal.ports.api" . }}
{{- $username := "natsadmin" -}}
{{- $password := randAlphaNum 15 -}}
{{- $htpasswd := htpasswd $username $password -}}

{{- $natConfig := dict
  "host" $host
  "port" $port
  "user" $username
  "password" $password
  "htpasswd" $htpasswd
-}}

{{/* check if secret exists and use that */}}
{{- $secretName := include "common.names.custom" (list . "nats") -}}
{{- $secretData := (lookup "v1" "Secret" .Release.Namespace $secretName).data -}}
{{- if $secretData }}
  {{- $username := index $secretData "NATS_USERNAME" | b64dec -}}
  {{- $password := index $secretData "NATS_PASSWORD" | b64dec -}}
  {{- $htpasswd := index $secretData "HTPASSWD" | b64dec }}
  {{- if not $htpasswd }}
    {{- $htpasswd = htpasswd $username $password -}}
  {{- end }}
  {{- $natConfig = dict
    "host" $host
    "port" $port
    "user" $username
    "password" $password
    "htpasswd" $htpasswd
  -}}
{{- end }}
{{- $natConfig | toYaml -}}
{{- end }}
