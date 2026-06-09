# Developer Build Runbook

## Goal

Deploy a temporary environment where one or more services can use images built from developer branches while the rest stay on the default baseline.

## Inputs

- `DEPLOYER_ID`
- `DOMAIN_NAME` for the storefront UI
- `BACKOFFICE_DOMAIN_NAME` for the backoffice UI
- optional per-service branch overrides for any service in `jenkins/services.env`

## Flow

1. Resolve the image tag for each service:
   - `main` stays `main`
   - any other branch resolves to its latest commit SHA
2. Generate `work/generated-values.yaml`.
3. Run `helm upgrade --install`.
4. Wait for rollout and print the resulting `domain:NodePort`.

## Expected output

- namespace `yas-user-<developer-id>`
- release `yas-<developer-id>`
- values file under `work/generated-values.yaml`
- distinct public endpoints for `storefront` and `backoffice`
