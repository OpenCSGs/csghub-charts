{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
agenticflow API token (44 hex), persisted in the master Secret under
"agenticflow-token" so it survives upgrades.
*/}}
{{- define "agenticflow.api.token" }}
  {{- include "common.secret.value" (list . "agenticflow-token" 44) -}}
{{- end }}
