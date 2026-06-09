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

## Important limitation

The actual YAS application source repository is not present in this workspace. That means this scaffold can prepare the delivery structure, but it cannot yet:

- build real service images
- render final service inventory from source
- validate Docker build paths
- deploy a working cluster release

## Suggested next steps

1. Clone `nashtech-garage/yas` into this workspace or merge these files into the real delivery repo.
2. Replace sample entries in `jenkins/services.env` and `helm/yas/values.yaml` with the real service list.
   The current entries are upstream-derived from the public YAS repo, but still need verification against the exact source tree you will deploy.
3. Validate one service end-to-end: Docker build, image push, Helm deploy.
4. Expand from one service to the full required YAS baseline.

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
- GitOps values updates
