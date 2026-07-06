# Status Report

Last updated: July 7, 2026

## Completed in this repository

- Assignment analysis and phased notes exist in `plan/`.
- Delivery scaffold exists for Jenkins, Helm, ArgoCD, and service-mesh work in `jenkins/`, `helm/`, `argocd/`, and `mesh/`.
- Cross-platform local helper set exists in `scripts/` for preflight, selftest, dry run, values generation, GitOps values generation, chart-values generation, service-catalog validation, chart validation, source alignment, and status reporting.
- Drift validators now cover the main hand-written docs and runbooks, including `README`, Jenkins and ArgoCD guides, mesh notes plus mesh test/result templates, service inventory, image matrix, troubleshooting, remaining-work plan, handover checklist, final report template, source build/runtime matrix, and the operational flow docs.
- Shared catalog exists in `jenkins/services.env` with 20 app services, 2 public entrypoints, and explicit `ui` versus `backend` workload typing.
- Frozen first-release baseline exists in `jenkins/services.release-baseline.env` so Jenkins can target the agreed initial deployable subset without losing the full catalog.
- Helm chart baseline is generated from the shared catalog and validates locally with `helm lint` and `helm template`.
- GitOps overlays under `argocd/values/` are generated from the same shared catalog rather than maintained manually.
- Local clone `yas-source-upstream/` is now used as the default evidence base for service paths, Dockerfiles, build commands, runtime ports, and upstream image naming, but it is expected to be cloned into the workspace rather than committed into this delivery repo.
- Final runtime evidence now exists for:
  - Kiali topology capture
  - Keycloak `yas-admin` login
  - product-to-media request chain
  - Jenkins multibranch commit-tagged image push

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

- No repo-level blocker remains for the final handoff bundle.
- The only remaining ambiguity is external rubric wording around whether CI evidence must show a literal GitHub webhook event or whether Jenkins multibranch automatic indexing plus commit-tagged image push is sufficient.
- The runtime evidence bundle already covers the rest of the rubric:
  - Kiali topology screenshot is captured.
  - Keycloak login for `yas-admin` is validated.
  - product -> media flow returns HTTP 200.
  - ArgoCD `dev` and `staging` are reported as Synced + Healthy in the latest state.

## Current recommendation

- Treat the repo as a strong, source-verified delivery scaffold with one successful real CI registry push already proven on Jenkins `8081`.
- Use the release-baseline subset as the first deployment subset because that is the exact group already proven in a real CI push.
- Treat the local `k3s` master verification as the handoff point from scaffold-only work to live cluster execution.
- Finish the cluster path in this order:
  - join the worker to the existing `k3s` master
  - create `yas-dev` and `yas-staging`
  - upload kubeconfig to Jenkins as `kubeconfig-file`
  - run `developer_build`, `developer_cleanup`, and one shared-environment deploy flow with evidence capture
- Keep `sampledata` and `search` outside the first end-to-end release until their workspace-specific test blockers are understood or intentionally bypassed.
- Treat `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, and `webhook` as deployable from a package-and-image perspective, but still not fully upstream-style verified on this host because their integration paths currently depend on unstable Keycloak Testcontainers startup.
- Move next to cluster setup and deploy verification only after providing a real Kubernetes path for Jenkins.

## Detailed remaining plan

- The detailed execution plan for unfinished work is in [remaining-work-plan.md](</D:/App/project2/docs/remaining-work-plan.md>).
- The short environment handover list is in [handover-checklist.md](</D:/App/project2/docs/handover-checklist.md>).
- The machine-generated per-service snapshot is available at [service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>) and is refreshed together with [status-report.generated.md](</D:/App/project2/work/status-report.generated.md>) when running `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks`.
- The generated drafting aid for the submission report is available at [final-report-notes.generated.md](</D:/App/project2/work/final-report-notes.generated.md>) and is refreshed by the same `refresh-evidence` command.
- The generated host capability snapshot is available at [host-capabilities.generated.md](</D:/App/project2/work/host-capabilities.generated.md>) and records which tools and runtime dependencies were actually reachable on the machine that produced the local evidence bundle.

## Inputs still required

- Worker-node connectivity to the local `k3s` master and kubeconfig access for Jenkins.
- Final decision on whether the cluster will be:
  - local lab
  - managed Kubernetes
  - on-prem
- Enough RAM for the intended cluster strategy if Jenkins and Kubernetes share the same machine:
  - about `4GB` for wiring-only checks
  - about `16GB` for limited local deployment trials
  - about `32GB` for a realistic all-in-one lab host
