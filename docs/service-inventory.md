# Service Inventory

This inventory was updated from a local clone of `nashtech-garage/yas` under `yas-source-upstream/` using the source tree, GitHub workflow files, Dockerfiles, Docker Compose files, and Kubernetes chart defaults on June 16, 2026.

The frozen first deployable subset is tracked in [jenkins/services.release-baseline.env](</D:/App/project2/jenkins/services.release-baseline.env>), while [jenkins/services.env](</D:/App/project2/jenkins/services.env>) remains the full source-verified catalog.

The current service-by-service verification snapshot is generated in [service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>) and is refreshed together with [status-report.generated.md](</D:/App/project2/work/status-report.generated.md>) when running `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks`.
Use [host-capabilities.generated.md](</D:/App/project2/work/host-capabilities.generated.md>) with that snapshot when deciding whether a missing verification result is a repo gap or only a host/runtime gap.

| Service | Runtime type | Path in repo | Dockerfile path | Container port | Expose outside cluster | NodePort | Workload type | Recommended first release | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| storefront | next.js | `storefront` | `storefront/Dockerfile` | `3000` | yes | `32080` | `ui` | yes | Public storefront UI; path and image naming are confirmed by upstream workflow. |
| backoffice | next.js | `backoffice` | `backoffice/Dockerfile` | `3000` | yes | `32081` | `ui` | yes | Public backoffice UI; path and image naming are confirmed by upstream workflow. |
| storefront-bff | spring-cloud-gateway | `storefront-bff` | `storefront-bff/Dockerfile` | `80` | no |  | `backend` | yes | Backend-for-frontend service. |
| backoffice-bff | spring-cloud-gateway | `backoffice-bff` | `backoffice-bff/Dockerfile` | `80` | no |  | `backend` | yes | Backend-for-frontend service. |
| product | spring-boot | `product` | `product/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| media | spring-boot | `media` | `media/Dockerfile` | `80` | no |  | `backend` | no | Keep for later unless the chosen demo flow proves it is required. |
| cart | spring-boot | `cart` | `cart/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| customer | spring-boot | `customer` | `customer/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| rating | spring-boot | `rating` | `rating/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| location | spring-boot | `location` | `location/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| order | spring-boot | `order` | `order/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| inventory | spring-boot | `inventory` | `inventory/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| tax | spring-boot | `tax` | `tax/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| search | spring-boot | `search` | `search/Dockerfile` | `80` | no |  | `backend` | no | Search is a separate compose profile upstream and also has a current workspace-specific test blocker. |
| promotion | spring-boot | `promotion` | `promotion/Dockerfile` | `80` | no |  | `backend` | no | Extra business capability; keep for a later increment unless the demo flow needs it. |
| payment | spring-boot | `payment` | `payment/Dockerfile` | `80` | no |  | `backend` | no | Payment orchestration service; add after the core CRUD baseline is stable. |
| payment-paypal | spring-boot | `payment-paypal` | `payment-paypal/Dockerfile` | `80` | no |  | `backend` | no | Payment provider plugin service; depends on the payment path being in scope. |
| recommendation | spring-boot | `recommendation` | `recommendation/Dockerfile` | `80` | no |  | `backend` | no | Source and CI are real, but it is a later increment for the first release plan. |
| sampledata | spring-boot | `sampledata` | `sampledata/Dockerfile` | `80` | no |  | `backend` | no | Exclude from the first release until the full test path is either fixed or intentionally bypassed. |
| webhook | spring-boot | `webhook` | `webhook/Dockerfile` | `80` | no |  | `backend` | no | Integration service evidenced by upstream CI badge. |

## Notes

- `storefront` and `backoffice` use the upstream `ui` chart defaults, which set `httpPort` and service port to `3000`.
- The Java services and BFFs use the upstream `backend` chart defaults, which set service HTTP port to `80` and metrics port to `8090`.
- `recommendation` and `sampledata` are now included because the local source clone confirms they have real Dockerfiles, CI workflows, and Helm charts.
- `Recommended first release` is a planning column, not a claim that the service is already deployed successfully.
- The current baseline file intentionally includes the `yes` entries from `Recommended first release`.
- Supporting infrastructure such as Keycloak, PostgreSQL, Kafka, Elasticsearch, pgAdmin, and observability are not listed in `jenkins/services.env` because they are infrastructure dependencies rather than app images built from the same service catalog.
