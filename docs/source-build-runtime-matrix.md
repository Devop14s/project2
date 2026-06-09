# Source Build And Runtime Matrix

This matrix is derived from the local clone [yas-source](</D:/App/project2/yas-source/README.md>) on June 9, 2026.

It combines evidence from:

- `yas-source/.github/workflows/*.yaml`
- `yas-source/*/Dockerfile`
- `yas-source/*/package.json`
- `yas-source/*/src/main/resources/application.*`

## Verified build evidence on this host

Checked directly in the cloned source:

- `storefront`: `npm ci` passed.
- `storefront`: `npm run build` passed.
- `storefront`: `npm run lint` passed.
- `storefront`: `npx prettier --check .` failed with formatting issues across many upstream files.
- `backoffice`: `npm ci` passed.
- `backoffice`: `npm run build` passed and produced `.next`, but the build log still printed `quill` SSR `document is not defined` traces after route generation.
- `backoffice`: `npm run lint` passed.
- `storefront-bff`: `mvn clean install -pl storefront-bff -am` passed using local Temurin 25 and Maven 3.9.11, and produced `storefront-bff/target/storefront-bff-1.0-SNAPSHOT.jar`.
- `backoffice-bff`: upstream-style `mvn clean verify -f backoffice-bff` passed using local Temurin 25 and Maven 3.9.11, and produced `backoffice-bff/target/backoffice-bff-1.0-SNAPSHOT.jar`.
- `product`: `mvn clean install -pl product -am` passed using local Temurin 25 and Maven 3.9.11, and produced `product/target/product-1.0-SNAPSHOT.jar`.
- `payment`: upstream-style `mvn clean install -pl payment -am` passed using local Temurin 25 and Maven 3.9.11, including tests and Testcontainers-backed integration flow, and produced `payment/target/payment-1.0-SNAPSHOT.jar`.
- `payment-paypal`: upstream-style `mvn clean install -pl payment-paypal -am` passed using local Temurin 25 and Maven 3.9.11, including unit-test coverage for the PayPal adapter, and produced `payment-paypal/target/payment-paypal-1.0-SNAPSHOT.jar`.
- `recommendation`: upstream-style `mvn clean install -pl recommendation -am` passed using local Temurin 25 and Maven 3.9.11 after rerunning sequentially; the earlier parallel attempt only failed because a shared `common-library/target` clean collided with another reactor build.
- `inventory`: upstream-style `mvn clean install -pl inventory -am` passed using local Temurin 25 and Maven 3.9.11, including test coverage, and produced `inventory/target/inventory-1.0-SNAPSHOT.jar`.
- `order`: upstream-style `mvn clean install -pl order -am` passed using local Temurin 25 and Maven 3.9.11, including test coverage, and produced `order/target/order-1.0-SNAPSHOT.jar`.
- `sampledata`: upstream-style `mvn clean install -pl sampledata -am` is currently blocked by `common-library` test compilation in this workspace, but packaging with `-Dmaven.test.skip=true` passed and produced `sampledata/target/sampledata-1.0-SNAPSHOT.jar`.
- `search`: upstream-style `mvn clean install -pl search -am` is currently blocked by `ProductCdcConsumerTest` because the Elasticsearch Testcontainers dependency does not become ready in this workspace, but packaging with `-Dmaven.test.skip=true` passed and produced `search/target/search-1.0-SNAPSHOT.jar`.
- Docker daemon is reachable outside the sandbox on this host.
- `docker build` for `product` passed and produced local image `yas-product:codex-verified`.
- `docker build` for `backoffice` passed and produced local image `yas-backoffice:codex-verified`.
- `docker build` for `storefront-bff` passed and produced local image `yas-storefront-bff:codex-verified`.
- `docker build` for `backoffice-bff` passed and produced local image `yas-backoffice-bff:codex-verified`.
- `docker build` for `payment` passed and produced local image `yas-payment:codex-verified`.
- `docker build` for `payment-paypal` passed and produced local image `yas-payment-paypal:codex-verified`.
- `docker build` for `recommendation` passed and produced local image `yas-recommendation:codex-verified`.
- `docker build` for `inventory` passed and produced local image `yas-inventory:codex-verified`.
- `docker build` for `order` passed and produced local image `yas-order:codex-verified`.
- `docker build` for `sampledata` passed and produced local image `yas-sampledata:codex-verified`.
- `docker build` for `search` passed and produced local image `yas-search:codex-verified`.
- `docker build` for `storefront` was attempted earlier but timed out before producing a local image.
- `helm lint helm/yas` passed with Helm 4.2.0.
- `helm template yas helm/yas` passed and rendered chart output locally.

## UI services

| Service | Source path | CI build steps | Docker context | Upstream image | Runtime port | Runtime command | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| storefront | `yas-source/storefront` | `npm ci`, `npm run build`, `npm run lint`, `npx prettier --check .` | `./storefront` | `ghcr.io/nashtech-garage/yas-storefront:latest` | `3000` | `node server.js` | Real build and lint were verified locally; prettier check failed upstream. |
| backoffice | `yas-source/backoffice` | `npm ci`, `npm run build`, `npm run lint`, `npx prettier --check .` | `./backoffice` | `ghcr.io/nashtech-garage/yas-backoffice:latest` | `3000` | `node server.js` | Real build and lint were verified locally; Docker image build also passed. Build logs still show post-build `quill` SSR traces. |

## BFF services

| Service | Source path | CI build command | Docker context | Upstream image | App port | Context path | Runtime command | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| storefront-bff | `yas-source/storefront-bff` | `mvn clean install -pl storefront-bff -am` | `./storefront-bff` | `ghcr.io/nashtech-garage/yas-storefront-bff:latest` | `8087` | n/a | `java -jar /app.jar` | Real Maven build and Docker image build were both verified locally. Routes to Next.js storefront in `application-prod.yaml`. |
| backoffice-bff | `yas-source/backoffice-bff` | `mvn clean verify -f backoffice-bff` | `./backoffice-bff` | `ghcr.io/nashtech-garage/yas-backoffice-bff:latest` | `8087` | n/a | `java -jar /app.jar` | Real Maven verify and Docker image build were both verified locally. Routes to Next.js backoffice in `application-prod.yaml`. |

## Backend services

| Service | Source path | CI build command | Docker context | Upstream image | App port | Context path | Runtime command | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| product | `yas-source/product` | `mvn clean install -pl product -am` | `./product` | `ghcr.io/nashtech-garage/yas-product:latest` | `8080` | `/product` | `java -jar /app.jar` | Real Maven build was verified locally, produced `target/product-1.0-SNAPSHOT.jar`, and the Docker image build also passed. |
| media | `yas-source/media` | `mvn clean install -pl media -am` | `./media` | `ghcr.io/nashtech-garage/yas-media:latest` | `8083` | none declared | `java -jar /app.jar` | No `server.servlet.context-path` in main properties. |
| cart | `yas-source/cart` | `mvn clean install -pl cart -am` | `./cart` | `ghcr.io/nashtech-garage/yas-cart:latest` | `8084` | `/cart` | `java -jar /app.jar` | Standard Spring Boot JAR packaging. |
| order | `yas-source/order` | `mvn clean install -pl order -am` | `./order` | `ghcr.io/nashtech-garage/yas-order:latest` | `8085` | `/order` | `java -jar /app.jar` | Real Maven build and Docker image build were both verified locally, including passing test coverage during the upstream-style reactor build. |
| location | `yas-source/location` | `mvn clean install -pl location -am` | `./location` | `ghcr.io/nashtech-garage/yas-location:latest` | `8086` | `/location` | `java -jar /app.jar` | Standard Spring Boot JAR packaging. |
| customer | `yas-source/customer` | `mvn clean install -pl customer -am` | `./customer` | `ghcr.io/nashtech-garage/yas-customer:latest` | `8088` | `/customer` | `java -jar /app.jar` | Standard Spring Boot JAR packaging. |
| rating | `yas-source/rating` | `mvn clean install -pl rating -am` | `./rating` | `ghcr.io/nashtech-garage/yas-rating:latest` | `8089` | `/rating` | `java -jar /app.jar` | Standard Spring Boot JAR packaging. |
| inventory | `yas-source/inventory` | `mvn clean install -pl inventory -am` | `./inventory` | `ghcr.io/nashtech-garage/yas-inventory:latest` | `8090` | `/inventory` | `java -jar /app.jar` | Real Maven build and Docker image build were both verified locally, including passing test coverage during the upstream-style reactor build. |
| tax | `yas-source/tax` | `mvn clean install -pl tax -am` | `./tax` | `ghcr.io/nashtech-garage/yas-tax:latest` | `8091` | `/tax` | `java -jar /app.jar` | Standard Spring Boot JAR packaging. |
| search | `yas-source/search` | `mvn clean install -pl search -am` | `./search` | `ghcr.io/nashtech-garage/yas-search:latest` | `8092` | `/search` | `java -jar /app.jar` | Search also appears in a separate compose profile upstream. |
| promotion | `yas-source/promotion` | `mvn clean install -pl promotion -am` | `./promotion` | `ghcr.io/nashtech-garage/yas-promotion:latest` | `8092` | `/promotion` | `java -jar /app.jar` | Standard Spring Boot JAR packaging. |
| webhook | `yas-source/webhook` | `mvn clean install -pl webhook -am` | `./webhook` | `ghcr.io/nashtech-garage/yas-webhook:latest` | `8092` | `/webhook` | `java -jar /app.jar` | Integration-style backend service. |
| recommendation | `yas-source/recommendation` | `mvn clean install -pl recommendation -am` | `./recommendation` | `ghcr.io/nashtech-garage/yas-recommendation:latest` | `8095` | `/recommendation` | `java -jar /app.jar` | Real Maven build and Docker image build were verified locally. First parallel build attempt only hit a shared-target cleanup conflict in `common-library`. |
| payment | `yas-source/payment` | `mvn clean install -pl payment -am` | `./payment` | `ghcr.io/nashtech-garage/yas-payment:latest` | `8081` | `/payment` | `java -jar /app.jar` | Real Maven build and Docker image build were both verified locally; tests exercised container-backed integration flow. |
| payment-paypal | `yas-source/payment-paypal` | `mvn clean install -pl payment-paypal -am` | `./payment-paypal` | `ghcr.io/nashtech-garage/yas-payment-paypal:latest` | `8093` | `/payment-paypal` | `java -jar /app.jar` | Real Maven build and Docker image build were both verified locally; test suite exercised the PayPal integration adapter. |
| sampledata | `yas-source/sampledata` | `mvn clean install -pl sampledata -am` | `./sampledata` | `ghcr.io/nashtech-garage/yas-sampledata:latest` | `8094` | `/sampledata` | `java -jar /app.jar` | Packaging and Docker image build were verified locally with `maven.test.skip=true`; full upstream-style test path is currently blocked by `common-library` test compilation in this workspace. |

## Notes

- The upstream UI workflows use Node 20.
- The upstream backend workflows use Maven multi-module builds from the repo root with `-pl <service> -am`.
- Local backend verification on this host used Temurin JDK 25.0.3 and Apache Maven 3.9.11 to match the upstream Java baseline.
- Local chart verification on this host used Helm 4.2.0 from `work/tools/helm-v4.2.0/windows-amd64/helm.exe`.
- The backend Dockerfiles expect a prebuilt JAR in `target/`; they are not multi-stage Maven builds.
- The scaffold still normalizes Kubernetes service port exposure to `80` for backend services, while the app processes themselves listen on ports such as `8080` to `8095` inside their own containers in local development.
