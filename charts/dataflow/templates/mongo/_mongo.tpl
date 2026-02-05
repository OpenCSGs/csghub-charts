{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{- /*
# MongoDB Readiness Check Template
# Creates a Kubernetes init container that waits for MongoDB service to become ready
# Verifies health endpoint before proceeding with pod startup
#
# Usage: {{ include "wait-for-mongo" (dict "ctx" . "service" $service) }}
#
# Dependencies:
#   - common.names.custom template (naming)
#   - common.image template (image reference helper)
*/}}
{{- define "wait-for-mongo" }}
{{- $ctx := .ctx }}
{{- $service := .service }}
{{- $mongoSvc := include "common.service" (dict "ctx" $ctx "service" "mongo") | fromYaml }}
{{- $mongoConfig := include "common.mongo.config" (dict "ctx" $ctx "service" $service) | fromYaml }}
- name: wait-for-mongo
  image: {{ include "common.image" (list $ctx $mongoSvc.image) }}
  imagePullPolicy: {{ or $mongoSvc.image.pullPolicy $ctx.Values.global.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -c
    - |
      {{- $mongoHost := printf "mongodb://%s:%s@%s:%v" $mongoConfig.user $mongoConfig.password $mongoConfig.host $mongoConfig.port }}
      until mongosh {{ $mongoHost }}/admin --eval "db.adminCommand('ping')" | grep "ok.*1";
      do
        echo 'Waiting for MongoDB to be ready...';
        sleep 5;
      done
      echo 'MongoDB is ready!'
{{- end }}
