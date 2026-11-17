{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Resolve an OAuth client credential of a Casdoor application.

The Casdoor instance is shared between charts (CSGHub, CSGShip), so the switch
and the external settings live in the global scope:

  global.casdoor.enabled                   bundled (true) or external (false)
  global.casdoor.external.endpoint         base URL of the external instance
  global.casdoor.external.existingSecret   Secret holding the JWT signing cert
  global.casdoor.external.applications.<role>.clientId / clientSecret

The role says who the credential belongs to (portal, admin, csgship), not how the
application is named in Casdoor: the applications of an external instance can be
named anything.

Bundled mode: the credential is derived deterministically from the master key,
which is the same value the Casdoor bootstrap registers for the application.

External mode: the configured value is used verbatim. A missing value fails the
render, so a misconfigured release is caught at install time instead of at the
first login.

Usage:
{{ include "common.casdoor.credential" (dict "ctx" . "role" "portal" "app" "CSGHub" "field" "clientId" "length" 20) }}
*/}}
{{- define "common.casdoor.credential" -}}
{{- $ctx := .ctx }}
{{- $global := $ctx.Values.global | default dict }}
{{- $external := dig "casdoor" "external" (dict) $global }}
{{- $applications := dig "applications" (dict) $external }}
{{- $configured := dig .role .field "" $applications }}
{{- if $configured }}
{{- $configured -}}
{{- else if dig "casdoor" "enabled" true $global }}
{{- include "common.secret.password" (list $ctx (printf "casdoor.%s.%s" .app .field) .length) -}}
{{- else }}
{{- fail (printf "global.casdoor.external.applications.%s.%s must be set when global.casdoor.enabled=false" .role .field) -}}
{{- end }}
{{- end }}
