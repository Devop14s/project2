# Save Point

Updated: 2026-07-04 18:40 +07

## Cluster state

- `k3s-master` is `Ready`.
- `k3s-master` runs on Tailscale-facing addresses:
  - `INTERNAL-IP = 100.96.101.91`
  - `EXTERNAL-IP = 100.96.101.91`
- The Kubernetes API on the master is reachable on:
  - `https://100.96.101.91:6443`
  - expected probe response without credentials: `401 Unauthorized`
- Current workers:
  - `k3s-worker` is `Ready`
    - `INTERNAL-IP = 100.82.170.68`
    - `EXTERNAL-IP = 100.82.170.68`
    - WSL memory configured to 18 GB class
    - observed Linux usable RAM: about `17.56 GiB`
    - node label already applied:
      - `node.yas.io/tier=large`
  - `desktop-brprq5f` still exists but is currently `NotReady`
    - `INTERNAL-IP = 100.93.138.20`
    - intended role: 10 GB worker / `small` tier
    - node label already applied:
      - `node.yas.io/tier=small`
- `k3s-master` has taint:
  - `node-role.kubernetes.io/control-plane=true:NoSchedule`
- `yas-dev` is partially redeployed:
  - master UI pods are healthy
  - backend pods have been rescheduled onto `k3s-worker`
  - `postgres-0` and several old pods are still stuck around the 10 GB worker outage and need that node back or a deliberate stateful cleanup before the app becomes healthy again

## What is running on master

Only control-plane, mesh, and core system components remain on `k3s-master`:

- `istio-system/istio-egressgateway`
- `istio-system/istio-ingressgateway`
- `istio-system/istiod`
- `istio-system/kiali`
- `istio-system/prometheus`
- `kube-system/coredns`
- `kube-system/local-path-provisioner`
- `kube-system/metrics-server`
- `kube-system/traefik`
- `kube-system/svclb-traefik-*`

- `yas-dev-storefront`
- `yas-dev-backoffice`
- `yas-dev-swagger-ui`

These three UI workloads are intentionally pinned to the master.

## Tailscale and WSL recovery note

- Master Tailscale IP changed during re-login and is now:
  - `100.96.101.91`
- The master was reconfigured to use Tailscale for k3s:
  - `node-ip: 100.96.101.91`
  - `node-external-ip: 100.96.101.91`
  - `advertise-address: 100.96.101.91`
  - `tls-san: 100.96.101.91`
  - `flannel-iface: tailscale0`
- During this reconfiguration, `k3s` on the master entered a crash loop with:
  - `Failed to start ContainerManager`
  - `system validation failed - wrong number of fields (expected 6, got 7)`
- Root cause was a Docker Desktop WSL mount injected into the master distro:
  - `/Docker/host`
  - source: `C:\Program Files\Docker\Docker\resources`
- The mount was removed inside WSL with:

```bash
sudo umount /Docker/host
```

- After unmounting `/Docker/host`, `k3s` on master recovered successfully.
- Detailed note saved in:
  - `note-docker-desktop-wsl-k3s.md`

## Current dev runtime state

- Confirmed browser entrypoints from the master Windows host work through the WSL NAT IP:
  - `http://172.17.123.111:32080` → storefront
  - `http://172.17.123.111:32081` → backoffice
  - `http://172.17.123.111:32082` → swagger-ui
- Current blockers are no longer Tailscale or k3s join.
- Current blocker is runtime placement/state:
  - `product` and other Java backends are on the new 18 GB worker but are not healthy yet
  - the old `postgres-0` instance is still tied to the 10 GB worker outage

## Configuration changes completed

### Helm chart

- Added default scheduling profiles:
  - `worker`: default profile for backend workloads, avoids control-plane nodes
  - `worker-small`: explicit profile for the 10 GB worker tier
  - `worker-large`: explicit profile for the 18 GB worker tier
  - `ui-on-master`: standard profile for `storefront`, `backoffice`, `swagger-ui`
- Added default resource profiles:
  - `ui`
  - `backend`
- Added per-service `ServiceAccount` generation.
- Added support for:
  - `replicaCount`
  - `serviceAccountName`
  - `nodeSelector`
  - `affinity`
  - `tolerations`
  - `resources`

Files:

- `helm/yas/values.yaml`
- `helm/yas/templates/deployment.yaml`
- `helm/yas/templates/serviceaccount.yaml`
- `scripts/generate-chart-values.sh`

### Environment overlays

- `dev`, `staging`, and developer template values now pin UI to the `ui-on-master` profile.
- `sampledata` now defaults to `replicaCount: 0`.
- Added optional overlay to place only the three public UIs on the master:
  - `helm/yas/values-ui-on-master.yaml`
- Added explicit two-worker dev split overlay:
  - `helm/yas/values-dev-dual-worker.yaml`
  - `worker-small`:
    - `product`
    - `cart`
    - `customer`
    - `order`
    - `inventory`
    - `tax`
  - `worker-large`:
    - `storefront-bff`
    - `backoffice-bff`
    - optional heavier services when enabled later

Files:

- `helm/yas/values-dev.yaml`
- `helm/yas/values-staging.yaml`
- `helm/yas/values-developer-template.yaml`
- `helm/yas/values-ui-on-master.yaml`

### GitOps values

- Updated GitOps value generation to stay aligned with:
  - UI-on-master for the three public UIs
  - worker-first scheduling for the remaining workloads
  - `sampledata: replicaCount: 0`
  - staging NodePort overrides
  - current image repositories
  - dev env overrides for DB/Kafka/Elasticsearch-backed services

Files:

- `argocd/values/dev-values.yaml`
- `argocd/values/staging-values.yaml`
- `scripts/generate-gitops-values.sh`
- `argocd/README.md`

### Jenkins deploy flow

- `jenkins/scripts/deploy-helm.sh` now supports:
  - `EXTRA_VALUES_FILES`
- This allows optional deployment with:
  - `helm/yas/values-ui-on-master.yaml`

### Static infra manifests

- Locked static infra workloads away from the control-plane with required node affinity:
  - `infra/postgres.yaml`
  - `infra/kafka.yaml`
  - `infra/elasticsearch.yaml`
- Added explicit worker-tier affinity:
  - `postgres` → `node.yas.io/tier=small`
  - `kafka` → `node.yas.io/tier=large`
  - `elasticsearch` → `node.yas.io/tier=large`

### Mesh/docs

- Updated mesh README to reflect:
  - per-service service accounts
  - apply order for mTLS and infra destination rules
- Updated deployment topology and workflow docs to reflect:
  - master taint
  - worker-first scheduling
  - optional UI-on-master overlay
  - NodePort host examples

Files:

- `mesh/README.md`
- `docs/deployment-topology.md`
- `docs/workflow-guide.md`
- `jenkins/README.md`

## Validation already run

The following checks passed after the changes:

- `sh scripts/validate-chart-values.sh`
- `helm lint helm/yas`
- `helm template yas helm/yas -f helm/yas/values.yaml -f helm/yas/values-dev.yaml`
- `sh scripts/validate-mesh-readme.sh`
- `sh scripts/validate-gitops-values.sh`
- `helm template yas helm/yas -f helm/yas/values.yaml -f helm/yas/values-dev-dual-worker.yaml`

## Intended deploy modes after worker recovery

### Standard default

UI goes to the master and backend stays on worker nodes:

```bash
helm upgrade --install yas-dev helm/yas -n yas-dev \
  -f helm/yas/values.yaml \
  -f argocd/values/dev-values.yaml
```

### Redundant safety overlay

The UI-on-master overlay can still be added for ad-hoc manual runs, but it is no longer required because the standard values already pin the three UI services to the master:

```bash
helm upgrade --install yas-dev helm/yas -n yas-dev \
  -f helm/yas/values.yaml \
  -f argocd/values/dev-values.yaml \
  -f helm/yas/values-ui-on-master.yaml
```

### Two-worker dev split

Node labels are already in place on the current node objects:

```bash
kubectl label node desktop-brprq5f node.yas.io/tier=small --overwrite
kubectl label node k3s-worker node.yas.io/tier=large --overwrite
```

```bash
helm upgrade --install yas-dev helm/yas -n yas-dev \
  -f helm/yas/values.yaml \
  -f helm/yas/values-dev-dual-worker.yaml
```

## Immediate next step

1. Wait for `desktop-brprq5f` to return to `Ready`.
2. Redeploy with:
   - `helm/yas/values-dev-dual-worker.yaml`
3. Re-check:
   - `postgres` on the 10 GB worker
   - BFFs on the 18 GB worker
   - `product/cart/customer/order/inventory/tax` on the 10 GB worker
4. Only then decide whether to enable heavier optional services (`media`, `search`, `kafka`, `elasticsearch`) on the 18 GB worker.

## 2026-07-04 live recovery result

The `yas-dev` environment is now healthy on the current 3-node layout:

- master (`k3s-master`)
  - `yas-dev-storefront`
  - `yas-dev-backoffice`
  - `yas-dev-swagger-ui`
- small worker (`desktop-brprq5f`)
  - `postgres-0`
  - `yas-dev-product`
  - `yas-dev-cart`
  - `yas-dev-customer`
  - `yas-dev-order`
  - `yas-dev-inventory`
  - `yas-dev-tax`
- large worker (`k3s-worker`)
  - `keycloak`
  - `yas-dev-storefront-bff`
  - `yas-dev-backoffice-bff`

### Fixes that made the recovery work

1. Added Keycloak runtime on the large worker:
   - `infra/keycloak.yaml`
   - service name `identity`
   - sidecar disabled on Keycloak pod
2. Added Istio `DestinationRule` overrides for Keycloak plaintext traffic:
   - host `identity`
   - host `identity.yas-dev.svc.cluster.local`
3. Added alias services in the chart so short in-cluster names exist:
   - `storefront`, `backoffice`, `swagger-ui`
   - `storefront-bff`, `backoffice-bff`
   - `product`, `cart`, `customer`, `order`, `inventory`, `tax`
4. Corrected backend/BFF container ports in `helm/yas/values-dev-dual-worker.yaml`:
   - `storefront-bff` / `backoffice-bff` → `8087`
   - `product` → `8080`
   - `cart` → `8084`
   - `customer` → `8088`
   - `order` → `8085`
   - `inventory` → `8090`
   - `tax` → `8091`
5. Added probe override support in `helm/yas/templates/deployment.yaml` and used TCP probes for the dev dual-worker overlay, because the generic actuator probe path was not valid across all upstream services.

### Last known good checks

```bash
kubectl -n yas-dev get deploy
kubectl -n yas-dev get pods -o wide
```

Expected result at this save-point:

- all `yas-dev` deployments show `1/1`
- new pods on workers show `2/2 Running`
- master UI pods show `1/1 Running`
