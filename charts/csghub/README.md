# CSGHub Helm Charts

This repository contains the Helm charts for deploying **CSGHub** components in Kubernetes clusters.

For detailed installation and configuration instructions, please refer to the official documentation:

- [Prerequisites](https://opencsg.com/docs/en/csghub/101/install/kubernetes/prerequisites)
- [Quick Start](https://opencsg.com/docs/en/csghub/101/install/kubernetes/quick_install)
- [Standard Deployment Guide](https://opencsg.com/docs/en/csghub/101/install/kubernetes/standard)

---

## Chart Components

| Chart       | Description |
|------------|-------------|
| **common** | Provides shared **Helm templates (tpl)** used by other charts. It does not deploy a service on its own. |
| **[csgship](https://opencsg.com/docs/en/csghub/101/install/kubernetes/csgship)** | Backend service for the IDE coding assistant **CodeSouler**, responsible for handling data shipping and task management. |
| **[dataflow](https://opencsg.com/docs/en/csghub/101/install/kubernetes/dataflow)** | A dataset processing chart, mainly for data preprocessing, cleaning, and transformation; integrates with **Label Studio** for labeling tasks. |
| **[runner](https://opencsg.com/docs/en/csghub/101/install/kubernetes/runner)** | Acts as a proxy deployed in the Kubernetes cluster, responsible for executing deployment tasks. |
| **agentichub** | Bundled agent orchestration hub. Provides **agenticflow**, **csgbot** and other agent components. |

---

## Key Updates

- The runner is now an agent, supporting both integrated and standalone deployments.
- Dataflow charts have been refactored to the latest version.
- Agent-sandbox upgraded to `0.5.4` with `v1beta1` storage-version CRDs; `crds_install.sh` now installs both gateway and agent-sandbox CRDs.
- Cross-chart `domain.*` and `endpoint.*` defines (csghub / minio / casdoor / aigateway) consolidated into the **common** library chart.

## External NATS

The default deployment includes NATS. To use an existing NATS server with
JetStream enabled, set the shared connection in your values file:

```yaml
global:
  nats:
    enabled: false
    external:
      url: "nats://USER:PASSWORD@nats.example.com:4222"
```

Alternatively, use `host`, `port` (default `4222`), `user` and `password` under
`global.nats.external`. The chart URL-encodes credentials supplied as separate
fields; credentials in a complete URL must already be URL-encoded. Omit `user`
and `password` for a server without authentication. `url` takes precedence over
the separate fields, and an external address is required when `enabled: false`.

This configuration is shared by the core backend services, XNet and bundled
CSGShip. External mode omits the built-in NATS StatefulSet, Service, ConfigMap
and Secret, skips the server's built-in NATS HTTP health wait, and removes
CSGShip's reference to the built-in NATS Secret. External servers do not need to
expose monitoring port 8222; the application establishes the NATS connection.
Standalone CSGShip continues to use its existing `billing.nats` settings.

When switching an existing installation, migrate JetStream data separately
before changing the connection. Existing PVCs and the retained NATS Secret are
not migrated by this setting. Connecting to an external cluster does not change
the application's JetStream stream replication settings.

## External Casdoor

The default deployment includes a bundled Casdoor instance. To point CSGHub at
a Casdoor instance you operate yourself, set `global.casdoor.enabled: false`
and supply the endpoint, JWT signing certificate Secret and application
credentials:

```yaml
global:
  casdoor:
    enabled: false
    external:
      endpoint: "https://sso.example.com"
      existingSecret: "csghub-casdoor-cert"
      applications:
        portal:
          clientId: "<portal client id>"
          clientSecret: "<portal client secret>"
```

The keys under `applications` are roles, not Casdoor application names: the
applications of an external instance can be named anything. `portal` is the
application the CSGHub portal logs into, `admin` the one used by the Temporal
and Superset consoles, and `csgship` the CSGShip one.

The chart then creates no Casdoor objects. You must pre-create the organization,
applications, JWT signing certificate and first administrator in your Casdoor
instance. The full step-by-step procedure, the FDW grants for administrator sync,
and a read-only verification script are in
[docs/external-casdoor.md](../../docs/external-casdoor.md).

## Support

For issues related to upgrades, deployments, or data migration, please [create an issue](https://github.com/OpenCSGs/csghub-charts/issues) in this repository.

---

_The CSGHub Support Team_
