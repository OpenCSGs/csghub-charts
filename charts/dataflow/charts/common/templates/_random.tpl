{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Generate a 32-bit random password
*/}}
{{- define "common.randomPassword" }}
  {{- $input := . }}
  {{- $minuteSeed := now | date "200601021504" }}
  {{- $base1 := printf "%s-%s-a" $input $minuteSeed | sha256sum | b64enc | replace "=" "" }}
  {{- $base2 := printf "%s-%s-b" $input $minuteSeed | sha256sum | b64enc | replace "=" "" }}
  {{- $base3 := printf "%s-%s-c" $input $minuteSeed | sha256sum | b64enc | replace "=" "" }}

  {{- $combined := print $base1 $base2 $base3 }}
  {{- $chars := splitList "" $combined }}

  {{- $result := "" }}
  {{- range $i := until 32 }}
    {{- $index := mod (add (mul $i 13) (len $minuteSeed)) (len $chars) }}
    {{- $result = printf "%s%s" $result (index $chars $index) }}
  {{- end }}

  {{- $result -}}
{{- end }}
