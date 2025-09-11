{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Get the port number by service name
*/}}
{{- define "csghub.svc.port" -}}
  {{- $serviceType := . -}}
  {{- $portMap := dict
      "server"       8080
      "user"         8080
      "accounting"   8086
      "payment"      8090
      "aigateway"    8084
      "dataviewer"   8093
      "moderation"   8089
      "notification" 8095
      "rproxy"       8083
      "runner"       8082
      "portal"       8090
      "loki"         3100
  -}}

  {{- if not (hasKey $portMap $serviceType) -}}
    {{- $validTypes := keys $portMap | sortAlpha | join ", " -}}
    {{- fail (printf "Invalid service type '%s'. Valid values: %s" $serviceType $validTypes) -}}
  {{- end -}}

  {{- get $portMap $serviceType -}}
{{- end -}}