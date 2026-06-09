# Jenkins Setup Notes

## Recommended jobs

- `yas-ci`
- `yas-developer-build`
- `yas-developer-cleanup`
- `yas-dev-cd`
- `yas-staging-release`

Each job can point to the same `Jenkinsfile` and pass a fixed `PIPELINE_TARGET`, or each job can load the corresponding pipeline script directly.

## Required Jenkins credentials

- `dockerhub-creds`: username/password credential
- `kubeconfig-file`: secret file credential for Kubernetes access
- `dockerhub-namespace-text`: optional secret text if you do not want to hardcode `DOCKERHUB_NAMESPACE`

## Required agent tools

- `git`
- `docker`
- `kubectl`
- `helm`
- `bash`

## Required environment values

- `DOCKERHUB_NAMESPACE` for pipelines that build or push images: `yas-ci`, `yas-developer-build`, `yas-dev-cd`, `yas-staging-release`, `yas-dev-gitops`, and `yas-staging-gitops`
- `SERVICES_FILE` if you want a direct-load Jenkins job to use something other than the default full catalog
- `SERVICE_CATALOG` as a simpler alternative to `SERVICES_FILE`, using either `release-baseline` or `full`
- `SOURCE_ROOT` when the service source tree is not checked out at the workspace root; leave it blank to auto-detect `yas-source/` or the workspace root
- `SOURCE_GIT_ROOT` when branch and commit resolution should use a different Git checkout than `SOURCE_ROOT`

## Service catalog format

`jenkins/services.env` uses this layout:

`service|path|dockerfile|port|expose|nodePort|workloadType`

Example:

`storefront|storefront|storefront/Dockerfile|3000|true|32080|ui`

The repository now keeps two catalogs:

- `jenkins/services.env`: full source-verified catalog
- `jenkins/services.release-baseline.env`: frozen first-release subset used by the top-level `Jenkinsfile` when `SERVICE_CATALOG=release-baseline`

## Developer build note

`jenkins/pipelines/developer_build.groovy` now exposes branch override parameters for the full service catalog and supports separate `DOMAIN_NAME` and `BACKOFFICE_DOMAIN_NAME` values for the two public UIs.

## Recommended first validation

1. Provide `DOCKERHUB_NAMESPACE` either as a Jenkins parameter or job environment value.
2. Decide whether the job should use `jenkins/services.release-baseline.env` or `jenkins/services.env`.
3. Run `jenkins/scripts/build-images.sh` locally in the agent environment.
4. Run `helm template demo helm/yas -f helm/yas/values.yaml`.

If this delivery repo lives beside a cloned YAS source tree under `yas-source/`, you can usually leave `SOURCE_ROOT` blank and let the scripts auto-detect it. Set `SOURCE_ROOT` explicitly only when the source checkout lives somewhere else. If branch and commit resolution should also come from that clone, leave `SOURCE_GIT_ROOT` unset and it will follow `SOURCE_ROOT` automatically when that directory contains `.git`.

Successful deploy and smoke-test runs now also leave runtime evidence under `work/runtime-evidence/<namespace>/<release>/`, including Helm status, pod/service snapshots, and the discovered public endpoints.

The shared-environment deploy jobs should follow the same pattern as the developer build:

- `yas-dev-cd` deploys to `yas-dev` and then runs `jenkins/scripts/smoke-test.sh`
- `yas-staging-release` deploys to `yas-staging` and then runs `jenkins/scripts/smoke-test.sh`

`jenkins/scripts/cleanup-release.sh` now uses the same environment-aware namespace and release defaults as the deploy helpers. With `ENVIRONMENT=dev` it targets `yas-dev`, with `ENVIRONMENT=staging` it targets `yas-staging`, and without an explicit environment it keeps the developer-style defaults from `DEPLOYER_ID`.

## GitOps note

`jenkins/scripts/update-manifest-repo.sh` now regenerates the full `argocd/values/*.yaml` file from the service catalog instead of editing only a few existing tag lines.
When the Jenkins checkout is detached, the same helper now also falls back from `BRANCH_NAME` to `GIT_BRANCH` before failing branch detection for the manifest push.

## Chart note

`helm/yas/values.yaml` is no longer just a hand-maintained baseline. It can be regenerated from `jenkins/services.env` through `scripts/generate-chart-values.ps1` or `scripts/generate-chart-values.sh`.
