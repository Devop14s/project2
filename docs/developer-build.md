# Developer Build Runbook

## Goal

Deploy a temporary environment where one or more services can use images built from developer branches while the rest stay on the default baseline.

## Inputs

- `DEPLOYER_ID`
- `DOMAIN_NAME` for the storefront UI
- `BACKOFFICE_DOMAIN_NAME` for the backoffice UI
- `SERVICE_CATALOG`, typically `release-baseline` for the first deployable subset or `full` for the complete catalog
- optional per-service branch overrides for any service in the chosen catalog
- registry access that can read the expected image repositories for the resolved tags

## Flow

1. Resolve the image tag for each service:
   - `main` stays `main`
   - any other branch resolves to its latest commit SHA
   - services in the chosen catalog stay enabled, while services outside it are explicitly disabled in the generated overlay
2. Log in to the registry and verify that each resolved image tag already exists remotely.
3. Generate `work/generated-values.yaml`.
4. Run `helm upgrade --install`.
5. Wait for rollout and print the resulting `domain:NodePort`.

## Expected output

- namespace `yas-user-<developer-id>`
- release `yas-<developer-id>`
- verified image list under `work/verified-image-list.txt`
- values file under `work/generated-values.yaml`
- distinct public endpoints for `storefront` and `backoffice`
- runtime evidence under `work/runtime-evidence/<namespace>/<release>/`

## Important prerequisite

`developer_build` still deploys prebuilt images; it does not build branch images itself. A non-`main` branch override must already have been built and pushed by CI under the expected commit-SHA tag, or the job now fails during the registry verification step before Helm deploy starts.
