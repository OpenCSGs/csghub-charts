{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate global unique HUB_SERVER_API_TOKEN

Usage:
{{ include "csghub.api.token" . }}

Parameters:
- ctx: Global context (e.g., .)

Returns: Unique API token string that changes on every installation
*/}}
{{- define "csghub.api.token" }}
  {{- $ctx := . }}

  {{- /* Generate random seed for uniqueness across installations */}}
  {{- $seed := now | date "200601021504" }}

  {{- /* Create unique hashes combining release info with random seed */}}
  {{- $namespaceHash := (printf "%s-%s" $ctx.Release.Namespace $seed | sha256sum) }}
  {{- $nameHash := (printf "%s-%s" $ctx.Release.Name $seed | sha256sum) }}

  {{- /* Combine hashes to form final token */}}
  {{- printf "%s%s" $namespaceHash $nameHash }}
{{- end }}

{{/*
Resolve service image with proper tag
Usage:
  {{ include "csghub.service.image" (dict "ctx" . "service" .Values.rproxy) }}
*/}}
{{- define "csghub.service.image" }}
{{- $service := .service }}
{{- $ctx := .ctx }}

{{- $baseImage := deepCopy (default (dict) $ctx.Values.image) }}
{{- $serviceImage := deepCopy (default (dict) $service.image) }}

{{- $tag := or (dig "image" "tag" "" $service) $baseImage.tag $ctx.Values.global.image.tag }}
{{- $finalTag := include "common.image.tag" (dict "ctx" $ctx "tag" $tag) }}

{{- $mergedImage := mergeOverwrite $baseImage $serviceImage }}
{{- $_ := set $mergedImage "tag" $finalTag }}

{{- $mergedImage | toYaml -}}
{{- end }}

{{/*
Generate clientId and clientSecret for a Casdoor application.

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