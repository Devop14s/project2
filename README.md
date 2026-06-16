# YAS CD Delivery Scaffold

This repository currently contains the assignment brief and an executable scaffold for the delivery repo that would host the YAS CD work.

## Current scope

- `plan/` contains the analysis and phased execution notes.
- `jenkins/` contains pipeline and shell-script skeletons.
- `helm/` contains a reusable Helm chart skeleton.
- `argocd/` contains GitOps application manifests and overlays.
- `mesh/` contains Istio and Kiali manifest skeletons.
- `docs/` contains runbooks, templates, and tracking documents.
- `scripts/` contains local validation helpers for this scaffold.
- [docs/source-build-runtime-matrix.md](</D:/App/project2/docs/source-build-runtime-matrix.md>) records source-verified build commands and runtime ports from the local `yas-source` clone.
- [docs/status-report.md](</D:/App/project2/docs/status-report.md>) summarizes what is already implemented in this repository and what still depends on external runtime access.
- [docs/remaining-work-plan.md](</D:/App/project2/docs/remaining-work-plan.md>) keeps the detailed next-phase execution plan for unfinished work.
- [docs/handover-checklist.md](</D:/App/project2/docs/handover-checklist.md>) is the short operator checklist for moving this repo into a real registry, Jenkins, and cluster environment.
- [work/service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>) is the current generated per-service verification snapshot, refreshed together with [work/status-report.generated.md](</D:/App/project2/work/status-report.generated.md>) by `powershell -ExecutionPolicy Bypass -File scripts\report-status.ps1 -SkipCommandChecks`.
- [work/final-report-notes.generated.md](</D:/App/project2/work/final-report-notes.generated.md>) is the current generated drafting aid for the submission report and is refreshed by the same `report-status` flow.
- `jenkins/services.release-baseline.env` freezes the first deployable subset while `jenkins/services.env` keeps the full source-verified catalog.

## Current limitation

The actual YAS application source repository is now cloned locally under [yas-source](</D:/App/project2/yas-source/README.md>), so service paths and Dockerfiles can be checked against real source. This workspace has already verified real local builds for `storefront`, `backoffice`, `storefront-bff`, `backoffice-bff`, `product`, `payment`, `payment-paypal`, `recommendation`, `inventory`, and `order`; test-skipped packaging for `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, `webhook`, `sampledata`, and `search`; and real local Docker image builds for the same verified services. Helm chart lint and template rendering were also validated locally with Helm 4.2.0, but the delivery repo still cannot yet:

The Jenkins helper scripts now understand `SOURCE_ROOT` and `SOURCE_GIT_ROOT`, so this delivery repo can target a sibling or nested source checkout such as `yas-source/` instead of assuming the application code lives at the delivery-repo root.

- build and push a full real image set
- deploy a working cluster release

## Suggested next steps

1. Replace demo registry values such as `docker.io/example` and configure real Jenkins credentials.
2. Validate one baseline service end to end: Docker build, image push, Helm deploy.
3. Expand from one service to the frozen release subset in `jenkins/services.release-baseline.env`, which now disables out-of-scope services explicitly in generated deploy overlays.

## Repository layout

```text
docs/               Runbooks, templates, and status tracking
argocd/             ArgoCD application and values overlays
mesh/               Istio and Kiali policy skeletons
helm/yas/           Helm chart scaffold
jenkins/pipelines/  Jenkins pipeline entrypoints
jenkins/scripts/    Reusable pipeline shell scripts
jenkins/services.env Service catalog used by scripts
scripts/            Local preflight and repo validation tools
plan/               Assignment analysis and execution plan
```

## Cross-platform note

Local helper scripts are provided in both `ps1` and `.sh` form under `scripts/` where practical, so the scaffold is usable on Windows and Linux/macOS hosts. The current cross-platform set covers:

- preflight checks
- local developer-build dry run
- branch-tag resolution
- generated-values rendering
- GitOps values generation
- Helm baseline values generation
- GitOps values updates
