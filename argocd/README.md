# ArgoCD Scaffold

This directory contains GitOps-oriented manifests that can be used if the team chooses the advanced ArgoCD track.

## Structure

- `app-dev.yaml`: ArgoCD `Application` for the `dev` namespace
- `app-staging.yaml`: ArgoCD `Application` for the `staging` namespace
- `values/`: environment-specific Helm values tracked by GitOps

## Placeholder values to replace

- repository URL
- target revision
- namespace
- image tags

