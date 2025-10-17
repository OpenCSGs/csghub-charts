{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Resolves the ClusterIP of CoreDNS service in kube-system namespace.

This template automatically detects the CoreDNS service (or legacy kube-dns service)
and returns its ClusterIP. It handles scenarios where the service might not exist
or might be named differently in various Kubernetes distributions.

USAGE:
  {{ include "coredns.system.ip" . }}

RETURNS:
  - ClusterIP string if CoreDNS/kube-dns service is found
  - Empty string if no DNS service is found

NOTES:
  - Requires Helm 3.0+ with lookup function enabled
  - Works with both CoreDNS and legacy kube-dns services
  - Returns empty string when running in template testing (helm template)
    since lookup function requires connection to Kubernetes API
*/}}
{{- define "coredns.system.ip" -}}
  {{- $serviceNames := list "kube-dns" "coredns" -}}
  {{- $kubeDNSClusterIP := "" -}}

  {{- range $serviceName := $serviceNames -}}
    {{- if not $kubeDNSClusterIP -}}
      {{- $service := (lookup "v1" "Service" "kube-system" $serviceName) -}}
      {{- if and $service $service.spec.clusterIP -}}
        {{- $kubeDNSClusterIP = $service.spec.clusterIP -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- /* Return the found ClusterIP or empty string */ -}}
  {{- $kubeDNSClusterIP | default "10.96.0.10" -}}
{{- end -}}

{{/*
Define the IP address of the self-managed CoreDNS service for CSGHub.

USAGE:
  {{ include "coredns.service.ip" . }}

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
{{- define "coredns.service.ip" -}}
{{- $kubeDNSClusterIP := include "coredns.system.ip" . -}}
{{- if $kubeDNSClusterIP }}
  {{- regexReplaceAll "[0-9]+$" $kubeDNSClusterIP "176" -}}
{{- else -}}
  {{- "10.96.0.176" -}}
{{- end -}}
{{- end }}