# Status Report

Last updated: June 16, 2026

## Completed in this repository

- Assignment analysis and phased notes exist in `plan/`.
- Delivery scaffold exists for Jenkins, Helm, ArgoCD, and service-mesh work in `jenkins/`, `helm/`, `argocd/`, and `mesh/`.
- Cross-platform local helper set exists in `scripts/` for preflight, selftest, dry run, values generation, GitOps values generation, chart-values generation, service-catalog validation, chart validation, source alignment, and status reporting.
- Drift validators now cover the main hand-written docs and runbooks, including `README`, Jenkins and ArgoCD guides, mesh notes plus mesh test/result templates, service inventory, image matrix, troubleshooting, remaining-work plan, handover checklist, final report template, source build/runtime matrix, and the operational flow docs.
- Shared catalog exists in `jenkins/services.env` with 20 app services, 2 public entrypoints, and explicit `ui` versus `backend` workload typing.
- Frozen first-release baseline exists in `jenkins/services.release-baseline.env` so Jenkins can target the agreed initial deployable subset without losing the full catalog.
- Helm chart baseline is generated from the shared catalog and validates locally with `helm lint` and `helm template`.
- GitOps overlays under `argocd/values/` are generated from the same shared catalog rather than maintained manually.
- Local clone `yas-source/` is now used as the evidence base for service paths, Dockerfiles, build commands, runtime ports, and upstream image naming.

## Verified locally on this host

- UI builds verified:
  - `storefront`: `npm ci`, `npm run build`, `npm run lint`
  - `backoffice`: `npm ci`, `npm run build`, `npm run lint`
- Backend and BFF builds verified with upstream-style Maven commands:
  - `storefront-bff`
  - `backoffice-bff`
  - `product`
  - `payment`
  - `payment-paypal`
  - `recommendation`
  - `inventory`
  - `order`
- Partial packaging verified:
  - `cart`: packaged successfully with `-Dmaven.test.skip=true`
  - `customer`: packaged successfully with `-Dmaven.test.skip=true`
  - `location`: packaged successfully with `-Dmaven.test.skip=true`
  - `media`: packaged successfully with `-Dmaven.test.skip=true`
  - `promotion`: packaged successfully with `-Dmaven.test.skip=true`
  - `rating`: packaged successfully with `-Dmaven.test.skip=true`
  - `tax`: packaged successfully with `-Dmaven.test.skip=true`
  - `webhook`: packaged successfully with `-Dmaven.test.skip=true`
  - `sampledata`: packaged successfully with `-Dmaven.test.skip=true`
  - `search`: packaged successfully with `-Dmaven.test.skip=true`
- Local Docker image builds verified:
  - `storefront`
  - `backoffice`
  - `storefront-bff`
  - `backoffice-bff`
  - `product`
  - `cart`
  - `customer`
  - `location`
  - `media`
  - `promotion`
  - `rating`
  - `tax`
  - `webhook`
  - `payment`
  - `payment-paypal`
  - `recommendation`
  - `inventory`
  - `order`
  - `sampledata`
  - `search`
- Local Helm verification completed:
  - `helm lint helm/yas`
  - `helm template yas helm/yas`

## Known blockers and gaps

- No real registry push has been verified yet for any service image.
- No Kubernetes cluster deployment has been verified yet for `dev`, `staging`, or developer namespaces.
- Jenkins webhook, Jenkins credentials, registry credentials, and kubeconfig wiring have not been exercised end to end.
- `sampledata` does not currently have a clean full upstream-style test pass in this workspace because `common-library` test compilation blocks the reactor build.
- `search` does not currently have a clean full upstream-style test pass in this workspace because Elasticsearch Testcontainers does not become ready for `ProductCdcConsumerTest`.
- `cart` does not currently have a clean full upstream-style test pass in this workspace because the integration path fails while waiting for the Keycloak Testcontainers health endpoint.
- `customer` does not currently have a clean full upstream-style test pass in this workspace because `UserAddressServiceIT` fails while Keycloak Testcontainers waits for the `/health/started` endpoint.
- `location` does not currently have a clean full upstream-style test pass in this workspace because controller integration tests fail while Keycloak Testcontainers waits for the `/health/started` endpoint.
- `media` does not currently have a clean full upstream-style test pass in this workspace because `MediaControllerIT` fails while Keycloak Testcontainers waits for the `/health/started` endpoint.
- `promotion` does not currently have a clean full upstream-style test pass in this workspace because `PromotionServiceIT` fails while Keycloak Testcontainers waits for the `/health/started` endpoint.
- `rating` does not currently have a clean full upstream-style test pass in this workspace because `RatingControllerIT` fails while Keycloak Testcontainers waits for the `/health/started` endpoint.
- `tax` does not currently have a clean full upstream-style test pass in this workspace because the integration path fails while waiting for the Keycloak Testcontainers health endpoint.
- `webhook` does not currently have a clean full upstream-style test pass in this workspace because `WebhookControllerIT` fails while Keycloak Testcontainers waits for the `/health/started` endpoint.

## Current recommendation

- Treat the repo as a strong, source-verified delivery scaffold rather than a finished deployment repo.
- Use the services already verified locally as the first deployment subset.
- Keep `sampledata` and `search` outside the first end-to-end release until their workspace-specific test blockers are understood or intentionally bypassed.
- Treat `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, and `webhook` as deployable from a package-and-image perspective, but still not fully upstream-style verified on this host because their integration paths currently depend on unstable Keycloak Testcontainers startup.

## Detailed remaining plan

- The detailed execution plan for unfinished work is in [remaining-work-plan.md](</D:/App/project2/docs/remaining-work-plan.md>).
- The short environment handover list is in [handover-checklist.md](</D:/App/project2/docs/handover-checklist.md>).
- The machine-generated per-service snapshot is available at [service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>) and is refreshed together with [status-report.generated.md](</D:/App/project2/work/status-report.generated.md>) when running `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks`.
- The generated drafting aid for the submission report is available at [final-report-notes.generated.md](</D:/App/project2/work/final-report-notes.generated.md>) and is refreshed by the same `refresh-evidence` command.

## Inputs still required

- Real registry namespace and Jenkins credential IDs.
- Reachable Jenkins host and Kubernetes cluster with kubeconfig access.
