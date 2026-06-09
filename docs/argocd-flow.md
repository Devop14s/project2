# ArgoCD Flow

## Goal

Use Jenkins only for build-and-update, then let ArgoCD reconcile the runtime state from Git.

## Proposed flow

1. Jenkins builds and pushes images.
2. Jenkins regenerates the environment values file under `argocd/values/` from the selected service catalog, usually `jenkins/services.release-baseline.env` for iteration 1 or `jenkins/services.env` for the full catalog.
3. The generated values file explicitly disables services outside the selected catalog so Helm does not inherit them from the full chart defaults.
4. The generated values file also carries `image.repository`, `image.tag`, and environment-specific ingress hosts so ArgoCD does not fall back to the placeholder registry entries in `helm/yas/values.yaml`.
5. Jenkins commits and pushes that manifest change.
6. ArgoCD watches the repo and syncs the target namespace.

For `dev_gitops`, the scaffold intentionally keeps the shared `main` tag in the committed overlay and relies on `work/commit_sha.txt` plus `work/commit-metadata.json` to identify which source revision the mutable `main` tag represented for that promotion run.

## Files in this repository

- `argocd/app-dev.yaml`
- `argocd/app-staging.yaml`
- `argocd/values/dev-values.yaml`
- `argocd/values/staging-values.yaml`
- `jenkins/pipelines/dev_gitops.groovy`
- `jenkins/pipelines/staging_gitops.groovy`
- `jenkins/scripts/update-manifest-repo.sh`
- `scripts/validate-argocd-apps.ps1`
- `scripts/validate-argocd-apps.sh`
- `scripts/generate-gitops-values.ps1`
- `scripts/generate-gitops-values.sh`

The ArgoCD app validators now also lock the expected repo URL, `targetRevision`, Helm chart path, environment values file, destination namespace, `CreateNamespace=true` sync option, and the intended sync policy split: `dev` stays auto-sync with `prune` and `selfHeal`, while `staging` stays manual-sync for explicit release control.

## Still required for real execution

- a reachable ArgoCD installation
- a Git repository that ArgoCD can watch
- credentials for Jenkins to push manifest updates
