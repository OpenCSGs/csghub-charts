# Agent Substrate chart and CSGHub integration design

Status: **chart scaffolded**, 2026-11-15. The standalone chart lives at
`charts/agent-substrate` and pins Substrate **v1.0.0** images on the OpenCSG
ACR. Runner integration and umbrella wiring remain draft; install and smoke-test
the standalone chart before enabling it for CSGHub product traffic.

The target is a separately operated Substrate control plane with WorkerPool
capacity for CSGHub's persistent-agent runtime. CSGHub retains ownership,
authorization, deployment records and agent lifecycle. The related Runner design
is `starhub-server/.specs/agent-substrate/agent_substrate_runtime_ee.md`; its
contracts are also draft and must be reconciled with this document before release.

## 1. Release and compatibility gate

**Pinned release: Substrate v1.0.0** (`b34fbee742906494b5eb4f1f36987176bf8770a4`).
Images: `opencsg-registry.cn-beijing.cr.aliyuncs.com/opencsghq/agent-substrate/substrate/*:v1.0.0`.
Verify the Runner client and chart against this same release. Do not mix the
v0.4 protocol, manifests or `ateom-*` images with v1 APIs or images solely
because their concepts have similar names.

| Contract | Proposed requirement | Release gate |
| --- | --- | --- |
| Substrate | One pinned release and source commit | Verify published images, digests, manifests, CRDs and upgrade path. |
| Runner | Client protocol matching the installation | Verify API fields, auth, retry behavior and compatibility during upgrades. |
| Kubernetes | Version, APIs, feature gates and signers required by that release | Test discovery and an actual install on every supported cluster distribution. |
| Nodes | Supported OS/architecture, mounts, ports, runtime and permissions | Verify gVisor and, if offered, microVM prerequisites against the selected release. |
| Storage | Supported PostgreSQL and snapshot object store | Verify version, TLS, credentials, permissions, backup and restore. |
| Upgrades | Supported control plane, worker, CRD and client version combinations | Document upgrade and rollback order before declaring support. |

The local upstream checkout inspected for this draft is commit `f20063021e1779fddc0340ffd22b1ce836877580`,
identified as `v0.4.0-52-gf2006302-dirty`; it is not a clean release and cannot
establish release compatibility. Its API guide describes matching
`ActorTemplate.workerSelector` against `WorkerPool.metadata.labels`, worker
resource limits as capacity, and sandbox-class matching as a scheduling gate.
Recheck all such details at the selected release commit.

## 2. Ownership and boundaries

| Owner | Responsibilities |
| --- | --- |
| Platform operator / chart | Install the pinned control plane, CRDs and node components; configure storage, trust, access and eligible WorkerPools; operate and upgrade them. |
| CSGHub Runner integration | Authenticate to the target cluster's control API and router; manage CSGHub-owned actors and templates; handle readiness, retries and lifecycle events. |
| CSGHub agent services | Ownership, user authorization, allocation and deployment identity, explicit lifecycle, audit and billing. |

A per-cluster switch alone is insufficient where Kubernetes and Substrate
sandboxes coexist. The Runner design must define persistent per-resource backend
identity, legacy fallback, lifecycle and recovery before enabling the chart for
CSGHub. This chart does not migrate existing sandboxes or their PVC data.

The chart must not contain per-user credentials or agent environment values.
The integration must establish how per-agent configuration, secrets and their
rotation work without leaking values through shared templates or snapshots.

### Connectivity and authorization

For an in-cluster Runner, define and verify the API endpoint, TLS server name,
trust bundle, projected service-account token audience and renewal, API access
grant, router endpoint and router authentication required by the pinned release.
The Runner chart must actually mount and configure these inputs; installing this
chart alone does not grant access. Limit the principal and network access to the
necessary control and data paths.

For a Runner outside the target cluster, Kubernetes `.svc` DNS and the Runner's
local service-account token cannot be assumed to reach or authenticate to the
remote installation. Specify a reachable endpoint, remote identity, TLS trust,
credential rotation and authorization for that cluster before supporting it.
Do not expose an unauthenticated router as an integration shortcut. Verify
header handling so a caller cannot select another actor by supplying its own
routing header.

## 3. Deployment model

Recommend a **standalone release** in a dedicated namespace such as
`ate-system`. An optional umbrella dependency can be considered after the
standalone chart works. A Helm subchart normally shares the umbrella release
namespace; it does not create a separate release merely by naming another
namespace. If embedded, template and test all namespace-dependent addresses,
certificate identities, service accounts, secrets and grants.

Expected components, subject to the selected release's manifests:

- API server and controller; router and egress components.
- Node agent, certificate/signing components and any required sidecars.
- Release-specific CRDs, default sandbox configuration and WorkerPools.
- PostgreSQL and snapshot storage connections, with optional bundled services
  only if their operations and recovery are designed and supported.

Keep the umbrella dependency disabled by default. Namespace and cluster-scoped
resources may be shared or installation-wide; define ownership before allowing
multiple releases in the same cluster.

## 4. Proposed values contract

Working chart-root keys live in `charts/agent-substrate/values.yaml`. Avoid
inheriting the CSGHub application's `global.image.tag`: its value applies to
other services and is not a Substrate release identifier.

```yaml
substrate:
  version: ""                 # required pinned release
  imageRegistry: ""           # registry with release-specific artifacts
  images: {}                  # component references, preferably pinned digests

objectStore:
  backend: ""                 # s3 | gcs
  snapshotLocation: ""        # gs://bucket/ (required even for S3)
  bucket: ""
  endpoint: ""
  region: cn-north-1
  pathStyle: true
  accessKey: ""
  secretKey: ""
  existingSecret: ""          # OBJECT_STORE_* keys; same contract as csghub/runner

agentgateway:
  requestParking:
    budget: 5s                # capacity-retry window (Agentgateway schema default)
    max: 1024
    retryInterval: 100ms
    retryFactor: 1.1
  requestTimeout: 180s        # >= wakeupProbe.timeoutSeconds + park budget

actorDefaults:
  wakeupProbe:
    timeoutSeconds: 120       # ActorTemplate probe; Substrate API default is 30
  egress:
    allowAll: true            # ships allow-all policy YAML for kubectl-ate / Runner

postgres:
  mode: external              # external or bundled, if supported
  external:
    existingSecret: ""        # connection details and role configuration

workerPools:
  - name: csghub-default
    namespace: ""             # defaults to the release namespace
    replicas: 3
    labels:
      csghub.opencsg.com/pool: csghub-default
    sandboxClass: gvisor
    resources:
      requests: {cpu: "1", memory: 2Gi}
      limits: {cpu: "4", memory: 16Gi}
    nodeSelector: {}
    tolerations: []

nodeLabeling:
  enabled: false              # operator controls node selection and upgrades
```

`replicas` and resource quantities above illustrate the schema, not sizing
recommendations. Require explicit image and storage configuration before an
install is considered supported. Ensure Secrets are referenced by name and
never render credential values into ConfigMaps, NOTES or logs.

For a standalone release the values file starts at the chart root, for example
`substrate:` and `workerPools:`. Under a future `csghub` umbrella dependency,
the same keys belong under `agent-substrate:`. Global values are inherited by
subcharts; integration must not overwrite unrelated CSGHub image settings.
`postgres.external.existingSecret` is the only external PostgreSQL secret path
in this proposal.

## 5. Capacity and placement contract

The Runner and chart must agree on a selector. For the example pool above, the
Runner's template selector would be
`csghub.opencsg.com/pool: csghub-default`, matching the **WorkerPool metadata
label**. The exact selector must be a documented integration input, not an
implicit pool name. Verify pool and atespace visibility and selection semantics
for the pinned release; do not infer a namespace requirement from the resource
names alone. In the inspected upstream checkout selection is by label rather
than namespace or RBAC; revalidate this for the release.

Validate the chosen sandbox class, referenced SandboxConfig, worker image,
resource limits, architecture, node selectors and tolerations as a single
contract. Worker capacity must accommodate each actor's declared limits as well
as runtime overhead. Define behavior for no matching pool, exhausted capacity,
missing assets and image pull failure. Provide dashboards and alerts for ready
capacity, placement failures and storage errors.

Do not render duplicate reserved selector keys. Merge user selectors first,
then set the validated release-specific version label, or reject a user
attempt to set that key. Derive node-label values and versioned resource names
using the selected release's rules, and test edge cases.

Autoscaling is deferred until an ownership model for `spec.replicas`, the HPA
metric, upgrade behavior and capacity limits is designed and tested. A static
Helm value and an HPA must not compete to set replicas.

## 6. Install and bootstrap design

1. Verify Kubernetes APIs, feature gates, signer and node prerequisites;
   validate registry access, storage endpoints and required credentials. Fail
   with actionable errors when a prerequisite is missing.
2. Install or explicitly upgrade the selected release's CRDs before rendering
   custom resources. Helm's `crds/` directory is install-only: define an
   explicit, reviewed CRD upgrade and compatibility process. Do not assume Helm
   adopts or upgrades pre-existing CRDs.
3. Create bootstrap service accounts and least-privilege RBAC **before** any
   hook job that uses them. If using pre-install hooks, the prerequisites also
   need appropriate hook ordering and lifecycle; ordinary chart resources are
   not available to a pre-install hook on first installation.
4. Create or reference the release-specific CA, JWT and other identity
   material. Preserve it across upgrades; never generate fresh signing keys on
   every render. Verify existing-secret format, idempotency, concurrent
   installs, rotation and recovery against the pinned upstream implementation.
5. Install the control plane, node components and pools. Ensure eligible nodes
   have the correct version labels through an operator-controlled mechanism
   that also covers new autoscaled nodes. Do not automatically relabel every
   node during an upgrade.
6. Configure the Runner identity and connectivity for each target cluster.
   Check actual WorkerPool readiness and execute an authenticated actor request.
   `helm --wait` alone does not establish that custom-resource capacity is ready.

Avoid assuming that an upstream installer image, CLI command or idempotency
behavior is available until verified in the pinned release. If a bootstrap job
is used, define its image, entrypoint, RBAC, timeouts, failure reporting and
cleanup explicitly.

## 7. Upgrade and rollback

Before an upgrade, verify the release compatibility matrix, CRD changes,
backup/restore, free worker capacity, actor drain behavior, and the correct
control plane, node agent, worker image and Runner order. An upgrade must have
an observable readiness gate and a rollback or recovery procedure.

If the selected release requires old and new versioned node-agent DaemonSets to
coexist, design their Helm ownership explicitly: merely changing a resource
name in a Helm release does not guarantee the old object remains. Preserve both
versions for the transition, move eligible nodes in controlled batches, observe
drain and actor recovery, and remove the old version only after verification.
Do not automate bulk relabeling. Determine how node-pool labels and newly added
nodes participate in both upgrade and rollback.

Pool changes, node termination and capacity shortages can interrupt running
actors. Verify actual drain, snapshot fidelity, restore and failure semantics;
do not promise lossless transitions without evidence. Document how an operator
recovers a failed or partially completed upgrade.

## 8. Data, security and operations

- **Identity material:** define ownership, backup, restore and rotation of
  signing keys and trust bundles. Existing identities must not be silently
  invalidated by reinstall or upgrade.
- **PostgreSQL:** specify schema and role ownership, connection/TLS secrets,
  supported migrations, backups, restore and rollback compatibility. A shared
  server requires isolated permissions; do not reuse CSGHub application roles.
- **Object storage:** specify bucket creation, access scope, TLS, endpoint,
  retention, versioning, backup, restore and orphan cleanup. Validate storage
  access from every component that needs it.
- **Actor data:** coordinate deletion and retention with the Runner design.
  Suspend, restart, upgrade, crash recovery and delete must each have explicit
  durability guarantees; snapshots and durable directories are not assumed to
  be equivalent to the existing PVC.
- **Observability:** monitor control-plane health, node agents, pool capacity,
  scheduling, snapshot and restore failures. Define the actor log and audit
  access path and prevent cross-user disclosure.
- **Cleanup:** inventory release-owned and shared resources before uninstall.
  Never recommend cluster-wide `--all` deletion as a default. CRDs, identities,
  database schemas and buckets need explicit ownership and retention decisions.

## 9. Verification and rollout gates

The following are **future acceptance tests**, not results from an existing
chart. Run them against the exact selected release and supported cluster matrix.

1. **Rendering:** lint and render standalone and umbrella values; verify image
   versions, value paths, namespace references, selectors, RBAC, secret
   references and absence of duplicate YAML keys. Test invalid required values.
2. **Fresh install:** provision prerequisites; verify CRD establishment,
   bootstrap ordering, control-plane readiness, trust, Runner grants and ready
   WorkerPool capacity. Check failure messages for missing prerequisites.
3. **End to end:** create a CSGHub-owned test actor, verify its placement and
   authenticated request through the Runner and router, suspend and resume it,
   and delete it according to the agreed lifecycle and retention contract.
4. **Failure and recovery:** exercise Runner/control-plane restart, unavailable
   capacity and storage, token rotation, duplicate operations and interrupted
   bootstrap; confirm reconciliation and no cross-actor access.
5. **Upgrade and rollback:** test supported version transitions, CRD handling,
   node-by-node drain, mixed-version ownership, failed upgrades and recovery,
   including newly added nodes. Verify data restoration rather than assuming it.
6. **Teardown and restore:** verify only owned resources are removed and restore
   the control plane and actor data from documented backups.

Implement the standalone chart only after the release and integration contracts
are agreed. Add umbrella wiring and operational automation after standalone
installation and recovery pass. Until then, keep this document and the Runner
design explicitly marked as drafts.
