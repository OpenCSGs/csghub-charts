{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
# Casdoor Domain Helper
# Generates the full domain name for Casdoor service based on configuration
# Usage: {{ include "common.domain.casdoor" . }}
# Returns: <subdomain>.<base-domain> or <base-domain> depending on useTop setting
*/}}
{{- define "common.domain.casdoor" -}}
{{- $service := include "common.service" (dict "service" "casdoor" "global" .) | fromYaml }}
{{- include "common.domain" (dict "ctx" . "sub" $service.name) -}}
{{- end }}

{{/*
# Casdoor External Endpoint Helper
# Generates the complete external access endpoint for Casdoor service
# Usage: {{ include "external.endpoint.casdoor" . }}
# Returns: Full URL (http://<domain> or https://<domain>) based on TLS configuration
*/}}
{{- define "common.endpoint.casdoor" }}
{{- include "common.endpoint" (dict "ctx" . "domain" (include "common.domain.casdoor" .)) -}}
{{- end }}

{{/*
Generate clientId and clientSecret for Casdoor application

Usage:
{{- $creds := include "csghub.casdoor.client" "YourAppName" | fromYaml -}}
clientId: {{ $creds.clientId }}
clientSecret: {{ $creds.clientSecret }}

Parameters:
- appName: Application name (string)

Returns: Dictionary with keys "clientId" and "clientSecret"
*/}}
{{- define "csghub.casdoor.client" -}}
{{- $appName := . -}}

{{- /* Generate seed based on timestamp */ -}}
{{- $seed := now | date "2006010215" -}}

{{- /* Generate clientId: 20 characters */ -}}
{{- $clientId := (printf "%s-clientId-%s" $appName $seed | sha256sum | replace " " "" | trunc 20) -}}

{{- /* Generate clientSecret: 40 characters */ -}}
{{- $clientSecret := (printf "%s-clientSecret-%s" $appName $seed | sha256sum | replace " " "" | trunc 40) -}}

{{- /* Output as YAML so it can be parsed into dict */ -}}
clientId: {{ $clientId }}
clientSecret: {{ $clientSecret }}
{{- end -}}

{{- /*
# Casdoor Readiness Check Template
# Creates a Kubernetes init container that waits for Casdoor service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-casdoor" . }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image.fixed template (image reference helper)
*/}}
{{- define "wait-for-casdoor" }}
{{- $service := include "common.service" (dict "service" "casdoor" "global" .) | fromYaml }}
{{- $serviceName := include "common.names.custom" (list . $service.name) -}}
- name: wait-for-casdoor
  image: {{ include "common.image.fixed" (dict "ctx" . "service" "" "image" "busybox:latest") }}
  imagePullPolicy: {{ or .Values.image.pullPolicy .Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      until wget --spider --timeout=5 --tries=1 "{{ printf "http://%s:%s" $serviceName ($service.service.port | toString) }}/api/health";
      do
        echo 'Waiting for Casdoor to be ready...';
        sleep 5;
      done;
      echo 'Casdoor is ready!'
{{- end }}