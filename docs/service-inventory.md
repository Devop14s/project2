# Service Inventory

This inventory was updated from the local clone [yas-source](</D:/App/project2/yas-source/README.md>) of `nashtech-garage/yas` using the source tree, GitHub workflow files, Dockerfiles, Docker Compose files, and Kubernetes chart defaults on June 9, 2026.

| Service | Runtime type | Path in repo | Dockerfile path | Container port | Expose outside cluster | NodePort | Workload type | Required for demo | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| storefront | next.js | `storefront` | `storefront/Dockerfile` | `3000` | yes | `32080` | `ui` | yes | Public storefront UI; path and image naming are confirmed by upstream workflow. |
| backoffice | next.js | `backoffice` | `backoffice/Dockerfile` | `3000` | yes | `32081` | `ui` | yes | Public backoffice UI; path and image naming are confirmed by upstream workflow. |
| storefront-bff | spring-cloud-gateway | `storefront-bff` | `storefront-bff/Dockerfile` | `80` | no |  | `backend` | yes | Backend-for-frontend service. |
| backoffice-bff | spring-cloud-gateway | `backoffice-bff` | `backoffice-bff/Dockerfile` | `80` | no |  | `backend` | yes | Backend-for-frontend service. |
| product | spring-boot | `product` | `product/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| media | spring-boot | `media` | `media/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| cart | spring-boot | `cart` | `cart/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| customer | spring-boot | `customer` | `customer/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| rating | spring-boot | `rating` | `rating/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| location | spring-boot | `location` | `location/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| order | spring-boot | `order` | `order/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| inventory | spring-boot | `inventory` | `inventory/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| tax | spring-boot | `tax` | `tax/Dockerfile` | `80` | no |  | `backend` | yes | Core business service. |
| search | spring-boot | `search` | `search/Dockerfile` | `80` | no |  | `backend` | optional | Search is a separate compose profile upstream and may be excluded from a minimal baseline. |
| promotion | spring-boot | `promotion` | `promotion/Dockerfile` | `80` | no |  | `backend` | optional | Extra business capability; keep if the chosen YAS baseline depends on it. |
| payment | spring-boot | `payment` | `payment/Dockerfile` | `80` | no |  | `backend` | optional | Payment orchestration service. |
| payment-paypal | spring-boot | `payment-paypal` | `payment-paypal/Dockerfile` | `80` | no |  | `backend` | optional | Payment provider plugin service. |
| recommendation | spring-boot | `recommendation` | `recommendation/Dockerfile` | `80` | no |  | `backend` | optional | Present in source, CI workflow, and K8s chart; commented out in the main compose baseline. |
| sampledata | spring-boot | `sampledata` | `sampledata/Dockerfile` | `80` | no |  | `backend` | optional | Present in source, CI workflow, and K8s chart; used for seed/sample data workloads. |
| webhook | spring-boot | `webhook` | `webhook/Dockerfile` | `80` | no |  | `backend` | optional | Integration service evidenced by upstream CI badge. |

## Notes

- `storefront` and `backoffice` use the upstream `ui` chart defaults, which set `httpPort` and service port to `3000`.
- The Java services and BFFs use the upstream `backend` chart defaults, which set service HTTP port to `80` and metrics port to `8090`.
- `recommendation` and `sampledata` are now included because the local source clone confirms they have real Dockerfiles, CI workflows, and Helm charts.
- Supporting infrastructure such as Keycloak, PostgreSQL, Kafka, Elasticsearch, pgAdmin, and observability are not listed in `jenkins/services.env` because they are infrastructure dependencies rather than app images built from the same service catalog.
