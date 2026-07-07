# Requirement Final Evidence

Date: 2026-07-08

This file is the short handover summary for the final state of the project.

## Requirement Sources

- `Project02_HKII_25_26.md` was checked for mandatory CD, ArgoCD advanced, Service Mesh advanced, and deliverable requirements.
- `Requirement-service.md` was checked for the required YAS demo service list.

## Cluster

- `k3s-master` is `Ready` on Tailscale IP `100.96.101.91`.
- `k3s-worker` is `Ready` on Tailscale IP `100.82.170.68`.
- The legacy `desktop-brprq5f` node still exists as `NotReady` and should be treated as stale.

## Runtime

- UI workloads are pinned to the master.
- Backend workloads run on the worker.
- `keycloak` is deployed and responding.
- `product` can reach `media` correctly after the direct-service routing fix.
- Final E2E checks pass for storefront UI, backoffice UI, swagger UI, Keycloak auth, product list/detail/brands, search catalog/suggest, cart items, media, and order list.

## Key Evidence

- Kiali topology screenshot:
  - `work/evidence/kiali-yas-dev-topology.png`
- Kiali graph JSON:
  - `work/evidence/kiali-yas-dev-graph.json`
- Retry proof:
  - `work/evidence-retry.txt`
- Authorization deny proof:
  - `work/evidence-mtls-deny.txt`
- Mesh snapshot:
  - `work/evidence-mesh-config.txt`
- CI evidence for commit-tagged image push:
  - `work/evidence/ci-image-evidence-build-5.txt`
- Jenkins multibranch trigger config evidence:
  - `work/evidence/jenkins-multibranch-trigger-config.xml`

## Final E2E Verification

- Storefront UI `32080`: HTTP 200
- Backoffice UI `32081`: HTTP 200
- Swagger UI `32082`: HTTP 200
- Keycloak realm `Yas`: OK
- `product /storefront/products`: PASS
- `product /storefront/product/{slug}`: PASS
- `product /storefront/brands`: PASS
- `search /storefront/catalog-search`: PASS
- `search /storefront/search_suggest`: PASS
- `cart /storefront/cart/items`: PASS
- `media /medias`: PASS
- `order /storefront/orders/my-orders`: PASS, empty array expected for a user with no orders

## Requirement-Service Mapping

- `product`: PASS
- `cart`: PASS
- `order`: PASS
- `customer`: PASS
- `inventory`: PASS
- `tax`: PASS
- `media`: PASS
- `search`: PASS
- `storefront-bff`: PASS
- `storefront-ui`: PASS
- `backoffice-bff`: PASS
- `backoffice-ui`: PASS
- `swagger-ui`: PASS
- `sampledata`: PASS as one-shot seeded workload; currently configured with `replicaCount: 0` after seeding

## Final Runtime Fix

- Commit `2d76d57` fixed the media VirtualService route.
- `mesh/api-gateway.yaml` now rewrites `/media/` to `/`.
- This makes public `/media/medias` traffic arrive at the media service as `/medias`, which is the endpoint the service actually exposes.

## CI / GitOps

- CI branch build pushed `luongtrz/yas-media:ab212ec`.
- Build was triggered automatically by Jenkins multibranch indexing, not by a manual build trigger.
- Dev and staging ArgoCD environments were reported as Synced and Healthy in the latest runtime state.

## Notes

- The delivery repo keeps the evidence files in `work/evidence/`.
- The project handover should cite the files above instead of referring to terminal output directly.
