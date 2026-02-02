{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate global unique HUB_SERVER_API_TOKEN

Usage:
{{ include "agenticflow.api.token" . }}

Parameters:
- global: Global context (e.g., .)

Returns: Unique API token string that changes on every installation
*/}}
{{- define "agenticflow.api.token" -}}
  {{- $global := . -}}

  {{- /* Generate random seed for uniqueness across installations */ -}}
  {{- $seed := now | date "200601021504" -}}

  {{- /* Create unique hashes combining release info with random seed */ -}}
  {{- $namespaceHash := (printf "%s-%s" $global.Release.Namespace $seed | sha1sum) -}}
  {{- $nameHash := (printf "%s-%s" $global.Release.Name $seed | sha1sum) -}}

  {{- /* Combine hashes to form final token */ -}}
  {{- printf "%s%s" $namespaceHash $nameHash | sha256sum | trunc 32 | b64enc -}}
{{- end -}}
