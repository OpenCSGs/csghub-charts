# Agent Substrate

Helm chart for [Agent Substrate](https://github.com/agent-substrate/substrate) **v1.0.0**.

Installs the control plane (`ateapi`, `atelet`, router/egress, …), CRDs, default `gvisor` SandboxConfig, optional bundled Postgres, and **WorkerPool** CRs from values. Images default to the OpenCSG ACR mirror.

This chart is the supported install path for CSGHub staging and other clusters. Do **not** use `ate-setup` in operator runbooks.

## Requirements

- Kubernetes 1.32+ (validated against ACK 1.34)
- Helm 3
- `kubectl-ate` **v1.0.0** (identity bootstrap only)
- Object storage bucket (S3 / MinIO / OSS-compatible) reachable from the cluster
- Nodes that can pull `opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/agent-substrate/substrate/*:v1.0.0`

## Install

```bash
# 1) Identity + namespaces (once per cluster)
#    Creates ate-system and podcertificate-controller-system if missing,
#    then CA/JWT pool Secrets via kubectl-ate (formats Helm cannot invent).
#    Re-run is safe: existing Secrets are kept.
./charts/agent-substrate/scripts/bootstrap-identity.sh ate-system

# 2) Install — object store comes from values (chart creates the Secret when
#    accessKey/secretKey are set). Prefer existingSecret / External Secrets in prod.
#    Keep namespace.create=false (default): Helm must not own Namespaces that
#    bootstrap already created (avoids meta.helm.sh ownership errors).
helm dependency update ./charts/agent-substrate
helm upgrade --install agent-substrate ./charts/agent-substrate \
  --namespace ate-system --create-namespace \
  -f charts/agent-substrate/examples/values-stg.yaml \
  --wait --timeout 20m
```

`--create-namespace` is a safety net if the release NS is missing; bootstrap
normally creates it. Do **not** set `namespace.create: true` after bootstrap
unless you first adopt those Namespaces with Helm ownership labels.

### Object store (configure once)

Either put credentials in values (chart creates `<release>-objectstore`):

```yaml
objectStore:
  backend: s3
  endpoint: https://oss-cn-beijing.aliyuncs.com
  region: cn-beijing
  bucket: opencsg-stg-agent-substrate
  # snapshotLocation defaults to gs://opencsg-stg-agent-substrate/
  accessKey: "..."
  secretKey: "..."
  pathStyle: true
```

Or reuse a pre-created Secret (`OBJECT_STORE_*` keys, same as csghub/runner):

```yaml
objectStore:
  backend: s3
  bucket: opencsg-stg-agent-substrate
  endpoint: https://oss-cn-beijing.aliyuncs.com
  region: cn-beijing
  existingSecret: substrate-objectstore
```

## Values (high level)

| Key | Purpose |
| --- | --- |
| `namespace.create` | Chart-managed Namespaces (release + `podcertificate-controller-system`); default **false** — use bootstrap / `--create-namespace` |
| `images.repo` / `images.tag` | Substrate image prefix and tag |
| `objectStore.*` | S3/GCS for `objectstore-plugin` + `snapshotLocation` (CSGHub `OBJECT_STORE_*` Secret keys) |
| `agentgateway.requestParking.*` | Capacity park window (default `5s` / `1024` / `100ms` / `1.1`) |
| `agentgateway.requestTimeout` | Until response headers; size ≥ wakeupProbe + park budget (default `180s`) |
| `actorDefaults.wakeupProbe.timeoutSeconds` | Suggested ActorTemplate probe timeout (default `120`) |
| `actorDefaults.egress.allowAll` | Ships allow-all egress policy YAML in ConfigMap (default `true`) |
| `postgres.bundled` | Upstream Postgres StatefulSet (stg/dev) |
| `workerPools[]` | `WorkerPool` CRs (name, replicas, labels, resources) |
| `workerPools[].hpa` | Optional HPA on the pool (`enabled: false` by default) |
| `atenet.dataplane` | `agentgateway` (default) |

See `values.yaml` and `examples/values-stg.yaml`.

## WorkerPools

Each entry under `workerPools` becomes an `ate.dev/v1` WorkerPool. The default label `csghub.opencsg.com/pool: csghub-default` is the Runner selector.

### Optional HPA

Set `workerPools[].hpa.enabled: true` to create an `autoscaling/v2` HPA that
scales the WorkerPool via `/scale` on
`ate_workerpool_workers{state=at_capacity}` (External AverageValue, default
`0.7` ≈ 30% idle headroom).

Prerequisites (not installed by this chart):

1. Prometheus scrapes `ate-api-server` `:9090/metrics`
2. prometheus-adapter exposes `ate_workerpool_workers` on `external.metrics.k8s.io`

When HPA is enabled, Helm uses `lookup` to keep the live `spec.replicas` on
upgrade so it does not reset the HPA; first install uses `hpa.minReplicas`.
Align `replicas` with `hpa.minReplicas` in values. The metric is most accurate
when workers are near one actor each; multi-slot workers understate fill.

## Upgrade / CRDs

Helm installs CRDs from `crds/` on first install only. CRD upgrades require a reviewed apply of newer CRD YAML from the pinned Substrate release.

## Actor defaults (wakeup + egress)

Helm installs ConfigMap `agent-substrate-actor-defaults` with:

- `wakeupProbe.timeoutSeconds` — set this on each ActorTemplate container probe
  (Substrate API default is 30; chart default is **120**)
- `egress-allow-all.yaml` — when `actorDefaults.egress.allowAll` is true

ActorTemplate / Actor / EgressPolicy are Substrate API objects. Create them with
Runner or `kubectl-ate`. Example allow-all apply:

```bash
kubectl ate create egress-policy -a <atespace> \
  -f charts/agent-substrate/examples/egress-allow-all.yaml
```

## Out of scope

- Creating ActorTemplate / Actor / EgressPolicy resources via Helm
- microVM sandbox class
- Embedding as a `csghub` umbrella subchart (planned later, disabled by default)

## Upstream pin

| Field | Value |
| --- | --- |
| Substrate | v1.0.0 (`b34fbee742906494b5eb4f1f36987176bf8770a4`) |
| Image repo | `opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/agent-substrate/substrate` |
