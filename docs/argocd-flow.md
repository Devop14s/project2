# ArgoCD Flow

## Goal

Use Jenkins only for build-and-update, then let ArgoCD reconcile the runtime state from Git.

## Proposed flow

1. Jenkins builds and pushes images.
2. Jenkins updates the environment values file under `argocd/values/`.
3. Jenkins commits and pushes that manifest change.
4. ArgoCD watches the repo and syncs the target namespace.

## Files in this repository

- `argocd/app-dev.yaml`
- `argocd/app-staging.yaml`
- `argocd/values/dev-values.yaml`
- `argocd/values/staging-values.yaml`
- `jenkins/pipelines/dev_gitops.groovy`
- `jenkins/pipelines/staging_gitops.groovy`
- `jenkins/scripts/update-manifest-repo.sh`

## Still required for real execution

- a reachable ArgoCD installation
- a Git repository that ArgoCD can watch
- credentials for Jenkins to push manifest updates

