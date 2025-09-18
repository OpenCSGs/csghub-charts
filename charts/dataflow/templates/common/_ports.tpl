{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Get the port number by service name
*/}}
{{- define "csghub.svc.port" -}}
  {{- $serviceType := . -}}
  {{- $portMap := dict
      "server"       8080
      "redis"        6379
      "postgresql"   5432
      "mongo"        27017
      "label-studio" 8002
      "dataflow"     8000
  -}}

  {{- if not (hasKey $portMap $serviceType) -}}
    {{- $validTypes := keys $portMap | sortAlpha | join ", " -}}
    {{- fail (printf "Invalid service type '%s'. Valid values: %s" $serviceType $validTypes) -}}
  {{- end -}}

  {{- get $portMap $serviceType -}}
{{- end -}}