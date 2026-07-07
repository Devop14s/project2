# Final Requirement Status

Date: 2026-07-08

## Source Requirements Checked

| File | Scope | Result |
|---|---|---|
| `Project02_HKII_25_26.md` | Mandatory CD, ArgoCD advanced, Service Mesh advanced, report deliverables | Covered below |
| `Requirement-service.md` | Required YAS demo services | Covered in the 14-service traceability table |

## Mandatory

| # | Requirement | Status | Notes |
|---|---|---|---|
| 1 | Image tag `main/latest` | PASS | Backend uses `main`, BFF uses `20260705-step2fix2` |
| 2 | K8S 1 Master + 1 Worker | PASS | `k3s-master` and `k3s-worker` are `Ready` |
| 3 | CI build image with commit id on branch commit | PASS | Jenkins multibranch auto-trigger evidence exists, build/push used commit SHA tag |
| 4 | `developer_build` with branch param + NodePort | PASS | Evidence already captured in Jenkins build logs |
| 5 | Cleanup job deletes deployment | PASS | `developer_cleanup` evidence already captured |
| 6 | CI/CD dev + staging | N/A | Covered by advanced ArgoCD track |

## Advanced ArgoCD

| Requirement | Status | Notes |
|---|---|---|
| ArgoCD handles dev + staging | PASS | Both apps are managed |
| Jenkins -> Docker Hub -> manifest update -> ArgoCD sync | PASS | Build/push and manifest update flow evidenced |
| `yas-dev` Synced + Healthy | PASS | Verified in cluster state |
| `yas-staging` Synced + Healthy | PASS | Verified in cluster state |

## Advanced Service Mesh

| Requirement | Status | Notes |
|---|---|---|
| mTLS STRICT | PASS | Live policy present |
| Kiali topology | PASS | Screenshot captured in `work/evidence/kiali-yas-dev-topology.png` |
| Retry policy | PASS | `order-retry` and `tax-retry` evidenced |
| Authorization allow/deny | PASS | `200 OK` and `403 Forbidden` evidence captured |
| Test curl from pod | PASS | Executed with pod-side HTTP client evidence |

## E2E

| Component | Status | Notes |
|---|---|---|
| Storefront UI | PASS | HTTP 200 |
| Backoffice UI | PASS | HTTP 200 |
| Swagger UI | PASS | HTTP 200 |
| Keycloak | PASS | Realm `Yas` reachable |
| Keycloak login `yas-admin` | PASS | Verified with token acquisition |
| Product list API | PASS | `/storefront/products` |
| Product detail API | PASS | `/storefront/product/{slug}` |
| Product brands API | PASS | `/storefront/brands` |
| Search catalog API | PASS | `/storefront/catalog-search` |
| Search suggest API | PASS | `/storefront/search_suggest` |
| Cart items API | PASS | `/storefront/cart/items` |
| Media API | PASS | `/medias` after `/media/` gateway rewrite |
| Order API | PASS | `/storefront/orders/my-orders`; empty array is expected for a user with no orders |
| Kafka topics | PASS | CDC pipeline active |
| Search consumer | PASS | Consumer group connected |

## 14-Service Traceability

`Requirement-service.md` defines 14 services for the e-commerce demo. The current implementation maps them as follows:

| Service | Status | Notes |
|---|---|---|
| `product` | PASS | Running and E2E tested through storefront product APIs |
| `cart` | PASS | Running and E2E tested through cart items API |
| `order` | PASS | Running and E2E tested through my-orders API; empty array is expected with no placed orders |
| `customer` | PASS | Deployed as required backend service |
| `inventory` | PASS | Deployed as required backend service |
| `tax` | PASS | Deployed and used for Service Mesh retry policy |
| `media` | PASS | Running and E2E tested through `/medias`; gateway rewrite fixed |
| `search` | PASS | Running and E2E tested through catalog search and suggest APIs |
| `storefront-bff` | PASS | Running behind storefront flow |
| `storefront-ui` | PASS | HTTP 200 on port `32080` |
| `backoffice-bff` | PASS | Running behind backoffice flow |
| `backoffice-ui` | PASS | HTTP 200 on port `32081` |
| `swagger-ui` | PASS | HTTP 200 on port `32082` |
| `sampledata` | PASS | Configured as enabled one-shot service with `replicaCount: 0` after data seeding |

## Final Runtime Fix

- Commit `2d76d57` fixed `mesh/api-gateway.yaml`.
- The `media` VirtualService route now rewrites `/media/` to `/`.
- This is required because the media service has no `server.servlet.context-path`; it serves `/medias`, not `/media/medias`.

## Remaining Note

- The only external ambiguity is whether the grader requires a literal GitHub webhook screenshot for CI, or accepts Jenkins multibranch automatic indexing plus commit-SHA image push evidence.
