# Remaining Work Plan

Last updated: June 16, 2026

## Goal

Move this repository from a source-verified delivery scaffold to a working YAS delivery repo with real image push, real Kubernetes deployment, and reproducible CI/CD evidence.

## Current cluster progress

As of June 27, 2026, the local lab cluster has moved beyond planning:

- A `k3s` control-plane node was brought up successfully on WSL2.
- `kubectl get nodes -o wide` returned the master node in `Ready`.
- Core cluster add-ons reached `Running`.
- The next blocking step is no longer cluster installation itself; it is finishing the worker join and connecting Jenkins to the live kubeconfig.

## Current baseline

- Service catalog is source-verified against the local `yas-source-upstream` clone.
- Jenkins should fetch that source checkout into `yas-source-upstream/` per workspace instead of relying on a nested Git repository committed inside this delivery repo.
- If the real environment uses a mirror, private fork, or release branch, wire it through `SOURCE_REPO_URL` and `SOURCE_REPO_REF` rather than editing the pipeline code.
- Helm chart and GitOps overlays are generated from the shared catalog.
- Local build evidence already exists for:
  - UI: `storefront`, `backoffice`
  - BFF: `storefront-bff`, `backoffice-bff`
  - backend: `product`, `payment`, `payment-paypal`, `recommendation`, `inventory`, `order`
- Local build-artifact evidence also exists for:
  - `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, `webhook`
  - `sampledata`, `search`
- Local image build evidence already exists for:
  - `storefront`, `backoffice`, `storefront-bff`, `backoffice-bff`, `product`, `payment`, `payment-paypal`, `recommendation`, `inventory`, `order`
  - `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, `webhook`
  - `sampledata`, `search`
- The current per-service verification snapshot is generated in [service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>), and the high-level summary lives in [status-report.md](</D:/App/project2/docs/status-report.md>).
- The current host/runtime capability snapshot is generated in [host-capabilities.generated.md](</D:/App/project2/work/host-capabilities.generated.md>) and shows which local tools and runtime dependencies were actually reachable when the evidence bundle was refreshed.
- Run `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks` before a handover or report-writing session so the generated evidence bundle stays in sync.

## Recommended first deployment subset

- `storefront`
- `backoffice`
- `storefront-bff`
- `backoffice-bff`
- `product`
- `cart`
- `customer`
- `location`
- `order`
- `inventory`
- `rating`
- `tax`

## Why this subset

- It keeps the public UI flows available.
- It includes the main CRUD-style business services already represented in the source catalog.
- It avoids introducing the known workspace-specific `search` and `sampledata` test blockers into the first release gate.
- It postpones optional or more integration-heavy services such as `payment`, `payment-paypal`, `recommendation`, `promotion`, and `webhook` until the core path is stable.

## Phase 1: Freeze the first release subset

Current status: the recommended subset is now frozen in [jenkins/services.release-baseline.env](</D:/App/project2/jenkins/services.release-baseline.env>) while [jenkins/services.env](</D:/App/project2/jenkins/services.env>) remains the full source-verified catalog.

### Prerequisites

- Team agrees on the exact service list for the first deployable baseline.
- Team decides whether `payment` is mandatory for the assignment demo.

### Steps

1. Confirm the frozen baseline still matches the team demo scope, especially whether `payment` must be pulled into iteration 1.
2. Keep optional services outside `jenkins/services.release-baseline.env` unless the demo path proves they are required.
3. Document any intentional exclusions in the final report.

### Deliverables

- Updated `jenkins/services.release-baseline.env`
- Updated `docs/service-inventory.md`
- Written baseline decision in the final report

### Exit criteria

- Everyone can state exactly which services in `jenkins/services.release-baseline.env` must build, push, deploy, and smoke-test in iteration 1.

## Phase 2: Verify image push to the real registry

### Prerequisites

- Real registry namespace exists.
- Jenkins has working credentials for registry login.
- Naming convention is finalized.

### Steps

1. Configure `DOCKERHUB_NAMESPACE` or the real registry equivalent in Jenkins.
2. Run one image push manually from Jenkins for a service already verified locally, preferably `product` or `storefront-bff`.
3. Confirm pushed tag, digest, and pull access from another environment.
4. Expand push validation to the full release subset.
5. Record which Jenkins agent or runtime host executed the successful push so the final report can separate host limitations from repo limitations.

### Deliverables

- Real pushed images for the chosen subset
- Stored image list with tags and digests
- Host or Jenkins-agent identity tied to the successful run
- Jenkins logs proving login, build, and push

### Exit criteria

- Every service in the chosen subset exists in the registry under the expected repository and tag.

## Phase 3: Validate Helm deployment on a real cluster

### Prerequisites

- Reachable Kubernetes cluster
- Working `kubectl` context
- Namespace creation permission
- Any required infra dependencies available or intentionally stubbed

### Steps

1. Join the worker node to the already-running local `k3s` master and verify `kubectl get nodes` shows both nodes in `Ready`.
2. Create the shared namespaces `yas-dev` and `yas-staging`.
3. Upload the live kubeconfig to Jenkins as credential `kubeconfig-file`.
4. Deploy one service plus its dependencies into a disposable namespace.
5. Validate generated values, rollout status, services, and ingress or `NodePort` exposure.
6. Expand to the full chosen subset.
7. Record namespace, release name, image tags, and resulting endpoints.

### Deliverables

- Successful `helm upgrade --install`
- Pod and service evidence
- One working public endpoint for `storefront`
- One working public endpoint for `backoffice`

### Exit criteria

- The chosen subset reaches Ready state and the public UI paths are reachable through the expected cluster entrypoint.
- Jenkins can target the same kubeconfig used for the local `k3s` master without manual kubectl fixes on every run.

## Phase 4: Exercise the Jenkins flows end to end

### Prerequisites

- Phase 2 and Phase 3 are working
- Jenkins jobs are created from the scaffold pipeline files

### Steps

1. Run the CI job on a branch push and verify image tags use commit SHA where intended.
2. Run `developer_build` with at least one branch override.
3. Run `developer_cleanup` and verify namespace deletion.
4. Run `dev_cd` or `dev_gitops`.
5. Run `staging_release` or `staging_gitops`.

### Deliverables

- Jenkins console logs
- Built image list per run
- Namespace and release evidence
- Screenshots for the report

### Exit criteria

- Every required Jenkins job has at least one successful execution with usable evidence.

## Phase 5: Close the known blockers

Current workspace blocker set:
- `sampledata`: `common-library` test compilation blocks the full reactor path.
- `search`: Elasticsearch Testcontainers does not become ready for `ProductCdcConsumerTest`.
- `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, `webhook`: Keycloak Testcontainers does not become healthy on `/health/started`.

### `sampledata` full test path

1. Capture the exact `common-library` test compilation failure from the workspace.
2. Decide whether the assignment requires fixing the underlying test issue or explicitly excluding `sampledata` from the baseline.

### `search` full test path

1. Reproduce `ProductCdcConsumerTest` with full logs.
2. Decide whether to fix local Elasticsearch/Testcontainers readiness or exclude `search` from the first release.

### Keycloak-blocked integration paths

1. Reproduce one representative failing service, preferably `customer` or `promotion`, with full logs and container lifecycle output.
2. Determine whether the host issue is image startup time, port availability, container resource pressure, or Docker networking.
3. Decide whether the assignment requires fixing the Keycloak startup path locally or accepting package-and-image verification for these services in the report.
4. If the blocker is fixed once, rerun the remaining Keycloak-blocked services to separate code issues from shared runtime issues.

### Exit criteria

- Each blocker is either resolved with evidence or explicitly excluded with written justification.

## Phase 6: Finish GitOps and service mesh evidence

### Prerequisites

- Cluster deployment is already working
- ArgoCD and Istio or the chosen mesh are installed

### Steps

1. Run Jenkins manifest-update flow and confirm ArgoCD sync.
2. Record ArgoCD application health and sync status.
3. Apply mesh policies and verify traffic or security behavior.
4. Capture screenshots and short interpretation notes.

### Deliverables

- ArgoCD sync evidence
- Mesh policy manifests applied successfully
- Observability or traffic screenshots

### Exit criteria

- GitOps and mesh sections are supported by real runtime evidence rather than scaffold-only files.

## Phase 7: Final report packaging

### Steps

1. Fill [final-report-template.md](</D:/App/project2/docs/final-report-template.md>) with actual team details and decisions.
2. Add screenshots, command output excerpts, endpoints, and image digests.
3. Export the final `.docx` or equivalent deliverable format required by the course.

### Exit criteria

- The final report can be submitted without referring back to unfinished TODOs in the repo.
