# Runner Helm Chart

The **Runner** chart deploys an execution **proxy agent** in the Kubernetes cluster.
It is responsible for executing deployment tasks for CSGHub.

## Features

- Acts as a proxy for deployment tasks
- Can run in integrated or standalone mode
- Configurable resources and environment variables
- Supports **Kourier** or **Gateway API** as Knative ingress provider
- Built-in EnvoyProxy integration for the Gateway API ingress mode

## Prerequisites

- Kubernetes 1.28+
- Helm 3.8+
- Knative Operator 1.22+ (installed as a dependency)
- Envoy Gateway 1.6+ (if using Gateway API ingress mode)

## Ingress Modes

The chart supports two ingress modes for Knative Serving:

### Kourier (default, legacy)

```yaml
knative:
  serving:
    ingress: kourier
```

Uses Kourier as the Knative ingress provider. The application endpoint is automatically set to `kourier-internal.knative-serving.svc.cluster.local`.

### Gateway API

```yaml
knative:
  serving:
    ingress: gateway-api
```

Uses Kubernetes Gateway API with Envoy Gateway. The chart creates:

- **GatewayClass** — `csghub-gateway`
- **Gateway (listeners)** — handles external HTTP/HTTPS traffic for the runner
- **Gateway (knative)** — handles Knative internal/external traffic
- **EnvoyProxy resources** — configures envoy deployment and service for both gateways

The application endpoint is automatically set to `{release}-envoy-knative.{namespace}.svc.cluster.local`.

## Configuration

See [values.yaml](values.yaml) for the full list of configurable parameters.

### Global Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.gateway.controllerName` | GatewayClass controller name | `gateway.envoyproxy.io/gatewayclass-controller` |
| `global.gateway.service.type` | Gateway service type | `LoadBalancer` |
| `global.gateway.external.domain` | Base external domain | `csghub.example.com` |
| `global.gateway.tls.enabled` | Enable TLS termination | `false` |
| `global.image.registry` | Global image registry | `docker.io` |
| `global.chartContext.isBuiltIn` | Deployed bundled with CSGHub | `false` |

### Runner Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `name` | Resource name | `runner` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8082` |
| `region` | Cluster region | `region-0` |
| `interval` | Communication interval (seconds) | `60` |
| `namespace` | User workload namespace | `spaces` |
| `applicationEndpoint` | Knative endpoint override | `""` (auto-detected) |
| `networkInterface` | Host network interface | `""` |
| `storageClassName` | StorageClass for spaces | `""` |

### Knative Serving

| Parameter | Description | Default |
|-----------|-------------|---------|
| `knative.serving.domain` | Domain suffix for Knative services | `example.com` |
| `knative.serving.ingress` | Ingress provider | `gateway-api` |
| `knative.serving.autoscaler.enableScaleToZero` | Scale to zero | `true` |
| `knative.serving.autoscaler.scaleToZeroPodRetentionPeriod` | Pod retention period | `60m` |

## Installation

```bash
helm repo add csghub https://charts.opencsg.com/csghub
helm install my-runner csghub/runner --values values.yaml
```

## Dependencies

| Dependency | Version | Condition |
|------------|---------|-----------|
| common | 0.2.2 | always |
| reloader | 2.2.7 | `reloader.enabled` |
| prometheus | 28.6.0 | `prometheus.enabled` |
| envoy (gateway-helm) | 1.6.7 | `envoy.enabled` |
| lws | v0.6.1 | `lws.enabled` |
| argo-workflows | 0.47.4 | `argo.enabled` |
| knative-operator | 1.22.1 | `knative.enabled` |
| volcano | 1.14.1 | `volcano.enabled` |
| agent-sandbox | 0.2.1 | `agent-sandbox.enabled` |

## Support

For issues related to upgrades, deployments, or data migration, please [create an issue](https://github.com/OpenCSGs/csghub-charts/issues) in this repository.

---

_The CSGHub Support Team_
