{{- /*
Copyright OpenCSG, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/ -}}

{{/*
Determine the cluster's internal domain.

This function attempts to detect the cluster domain by checking:
1. kube-dns ConfigMap in kube-system namespace
2. CoreDNS ConfigMap in kube-system namespace
3. Falls back to "cluster.local" if unable to detect

Usage: {{ include "common.domain.cluster" . }}
*/}}
{{- define "common.domain.cluster" }}
  {{- $clusterDomain := "" }}

  {{- /* Try to get domain from kube-dns ConfigMap */}}
  {{- $kubeDNS := (lookup "v1" "ConfigMap" "kube-system" "kube-dns") }}
  {{- if $kubeDNS }}
    {{- if $kubeDNS.data.domain }}
      {{- $clusterDomain = $kubeDNS.data.domain }}
    {{- end }}
  {{- end }}

  {{- /* Fallback to CoreDNS ConfigMap */}}
  {{- if not $clusterDomain }}
    {{- $coreDNS := (lookup "v1" "ConfigMap" "kube-system" "coredns") }}
    {{- if $coreDNS }}
      {{- if $coreDNS.data.Corefile }}
        {{- if contains "cluster.local" $coreDNS.data.Corefile }}
          {{- $clusterDomain = "cluster.local" }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- /* Final fallback to default cluster domain */}}
  {{- if not $clusterDomain }}
    {{- $clusterDomain = "cluster.local" }}
  {{- end }}

  {{- $clusterDomain -}}
{{- end -}}