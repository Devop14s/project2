# Developer Build Runbook

## Goal

Deploy a temporary environment where one or more services can use images built from developer branches while the rest stay on the default baseline.

## Inputs

- `DEPLOYER_ID`
- `DOMAIN_NAME`
- optional per-service branch overrides such as `TAX_BRANCH` or `PRODUCT_BRANCH`

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

