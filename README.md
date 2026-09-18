# CSGHub Helm Charts

Helm charts for deploying [CSGHub](https://opencsg.com) and its companion services on Kubernetes.

## Overview

CSGHub is an open-source platform for managing Large Language Model assets — datasets, spaces, code, and models — via web UI, Git CLI, SDK, or chatbot. This repository hosts the charts that package CSGHub and the surrounding data, agent, and runtime services into a single deployable stack.

The `csghub` chart is an umbrella chart that bundles CSGHub and its optional companion services, each toggleable so you can deploy only what you need.

## Charts

| Chart | Description |
| --- | --- |
| [csghub](./charts/csghub) | Umbrella chart. Deploys the full CSGHub platform with all required components. |
| [dataflow](./charts/dataflow) | OpenCSG dataflow — data processing platform built on large model technology. |
| [agentichub](./charts/agentichub) | Agent module for developing, configuring, running, and collaborating on AI agents. |
| [agent-sandbox](./charts/agent-sandbox) | Isolated, stateful singleton workloads for AI agent runtimes. |
| [runner](./charts/runner) | Deploys and manages application instances inside a Kubernetes cluster. |
| [common](./charts/common) | Library chart with reusable templates and standardized configurations. |

## Requirements

- Kubernetes (validated against **1.32** in `ct.yaml`)
- Helm **v3** or **v4**
- Optional: `helm-unittest` plugin, `chart-testing` (`ct`), `yamllint`, `lefthook`

## Quick Start

Add the chart repository and install the umbrella chart:

```bash
helm repo add csghub https://charts.opencsg.com/csghub
helm repo update

helm install csghub csghub/csghub \
  --namespace csghub --create-namespace \
  -f custom-values.yaml
```

`custom-values.yaml` is where you override image tags, dependencies, and per-component toggles. See each chart's `values.yaml` for the full set of options.

## Sub-chart selection

Each component under `csghub` can be turned on or off independently via top-level flags. Out of the box the chart enables runner, dataflow, agentichub, prometheus, and envoy; toggle off what you don't need:

```yaml
# custom-values.yaml
dataflow:
  enabled: true
runner:
  enabled: true
agentichub:
  enabled: false
reloader:
  enabled: true
prometheus:
  enabled: false
```

See each chart's `values.yaml` for the full set of fields.

## Development

Local hooks (via [lefthook](https://github.com/evilmartians/lefthook)) cover the common checks. Install once:

```bash
lefthook install
```

| Command | What it does |
| --- | --- |
| `lefthook run pre-commit` | Builds chart deps, dry-runs templates, runs `helm-unittest`, validates YAML. |
| `lefthook run pre-push` | Runs `ct lint` against every chart. |
| `helm dependency build charts/<name>` | Refreshes vendored sub-charts under `charts/<name>/charts/`. |
| `helm unittest charts/<name> --with-subchart=false` | Runs unit tests for a single chart. |

Before opening a PR, make sure the chart `version` in `Chart.yaml` is bumped whenever templates change (`check-version-increment` is enforced).

## Docs

- [CSGHub](https://opencsg.com/docs/csghub/101/install/summary)

## Issues

For version upgrades, data migration, or other support, please [open an issue](https://github.com/OpenCSGs/csghub-charts/issues).

## License

Apache 2.0. See [LICENSE](./LICENSE).