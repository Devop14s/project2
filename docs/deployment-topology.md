# Deployment Topology

## Namespaces

- `yas-dev`
- `yas-staging`
- `yas-user-<developer-id>`

## Release names

- `yas-dev`
- `yas-staging`
- `yas-<developer-id>`

## Access pattern

- Internal services use `ClusterIP`.
- User-facing entrypoints use `NodePort`.
- Developers map hostnames manually in the local `hosts` file to the worker-node IP.
- Shared deploy helpers now default public UI hosts by environment: `*-<developer-id>.yas.local` for developer runs, `*-dev.yas.local` for `dev`, and `*-staging.yas.local` for `staging`.
- `k3s-master` is tainted with `node-role.kubernetes.io/control-plane=true:NoSchedule`.
- The chart now pins the three public UI workloads (`storefront`, `backoffice`, `swagger-ui`) to the master and leaves backend workloads on worker nodes by default.

## Scheduling model

- Default chart behavior:
  - `storefront`, `backoffice`, and `swagger-ui` use the `ui-on-master` profile.
  - all other services inherit the `worker` profile.
- `worker` profile: requires a node that does not carry the `node-role.kubernetes.io/control-plane` label.
- `worker-small` profile: requires `node.yas.io/tier=small`.
- `worker-large` profile: requires `node.yas.io/tier=large`.
- `ui-on-master` profile: only `storefront`, `backoffice`, and `swagger-ui` should ever tolerate the control-plane taint.
- Static infra manifests in `infra/` also require non-control-plane nodes.
- Planned two-worker split:
  - `worker-small` (10 GB): `postgres`, `product`, `cart`, `customer`, `order`, `inventory`, `tax`
  - `worker-large` (18 GB): `storefront-bff`, `backoffice-bff`, `kafka`, `elasticsearch`, and any optional heavier backend services when enabled

## Node labels for the two-worker split

- `desktop-brprq5f` should carry:
  - `node.yas.io/tier=small`
- `k3s-worker` should carry:
  - `node.yas.io/tier=large`

## Recommended overlays

- Standard deploy: `helm/yas/values.yaml` plus the environment values file only.
- `helm/yas/values-ui-on-master.yaml` remains available as a redundant safety overlay for manual ad-hoc runs, but the main values files already pin the three UIs to the master.
- Two-worker dev split:
  - `helm/yas/values-dev-dual-worker.yaml`
- Keep `sampledata` at `replicaCount: 0` by default in shared environments and only scale it up for a one-time seed run.

## Example host mapping

| Environment | Hostname | NodePort |
| --- | --- | --- |
| developer | `storefront-<developer-id>.yas.local` | `32080` |
| dev | `storefront-dev.yas.local` | `32080` |
| staging | `storefront-staging.yas.local` | `32080` |
