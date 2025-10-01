{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Define the IP address of the self-managed CoreDNS service for CSGHub.

USAGE:
  {{ include "rproxy.service.ip" . }}

DETAILS:
  - This template derives a custom CoreDNS ClusterIP for CSGHub
    based on the existing system CoreDNS IP.
  - It replaces the last octet of the system CoreDNS IP with `166`
    to avoid conflicts and keep consistency.
  - If the system CoreDNS IP cannot be determined, an empty string
    will be returned instead of breaking the rendering.

NOTES:
  - Ensure that the regex matches the expected IPv4 format.
  - The last octet substitution ensures compatibility with common
    Kubernetes service CIDR conventions.
*/}}
{{- define "rproxy.service.ip" -}}
{{- $kubeDNSClusterIP := include "coredns.system.ip" . -}}
{{- if $kubeDNSClusterIP }}
  {{- regexReplaceAll "[0-9]+$" $kubeDNSClusterIP "149" -}}
{{- else -}}
  {{- "10.96.0.150" -}}
{{- end -}}
{{- end }}