# ArgoCD Scaffold

This directory contains GitOps-oriented manifests that can be used if the team chooses the advanced ArgoCD track.

## Structure

- `app-dev.yaml`: ArgoCD `Application` for the `dev` namespace
- `app-staging.yaml`: ArgoCD `Application` for the `staging` namespace
- `values/`: environment-specific Helm values tracked by GitOps

## Placeholder values to replace

- target revision
- namespace
- image tags when your real release strategy differs from the current scaffold

## Current scaffold behavior

- `app-dev.yaml` and `app-staging.yaml` already point to this GitHub repository.
- `argocd/values/*.yaml` can be regenerated from either `jenkins/services.release-baseline.env` or `jenkins/services.env` with the local `generate-gitops-values` helpers, and `SERVICE_CATALOG=release-baseline` now selects the smaller iteration-1 subset automatically.
