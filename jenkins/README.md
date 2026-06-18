# Jenkins Setup Notes

## Recommended jobs

- `yas-ci`
- `yas-developer-build`
- `yas-developer-cleanup`
- `yas-dev-cd`
- `yas-staging-release`

Each job can point to the same `Jenkinsfile` and pass a fixed `PIPELINE_TARGET`, or each job can load the corresponding pipeline script directly. The top-level `Jenkinsfile` now carries the superset of shared parameters used by the dispatched pipelines, scopes flow-specific defaults by `PIPELINE_TARGET`, and the pipeline-specific Groovy files skip `properties(...)` rewrites when they are executed through that dispatcher.

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

- `DOCKERHUB_NAMESPACE` for pipelines that build, push, or verify remote image tags: `yas-ci`, `yas-developer-build`, `yas-dev-cd`, `yas-staging-release`, `yas-dev-gitops`, and `yas-staging-gitops`
- `SERVICES_FILE` if you want a direct-load Jenkins job to use something other than the default full catalog
- `SERVICE_CATALOG` as a simpler alternative to `SERVICES_FILE`, using either `release-baseline` or `full`
- `SOURCE_ROOT` when the service source tree is not checked out at the workspace root; leave it blank to auto-detect `yas-source-upstream/`, then `yas-source/`, then the workspace root
- `SOURCE_GIT_ROOT` when branch and commit resolution should use a different Git checkout than `SOURCE_ROOT`
- `SOURCE_REPO_URL` when the Jenkins agent should clone YAS from a mirror, private fork, or alternate Git remote instead of the public upstream URL
- `SOURCE_REPO_REF` when the Jenkins agent should clone a branch, tag, or ref other than `main`

## Service catalog format

`jenkins/services.env` uses this layout:

`service|path|dockerfile|port|expose|nodePort|workloadType`

Example:

`storefront|storefront|storefront/Dockerfile|3000|true|32080|ui`

The repository now keeps two catalogs:

- `jenkins/services.env`: full source-verified catalog
- `jenkins/services.release-baseline.env`: frozen first-release subset used by the top-level `Jenkinsfile` when `SERVICE_CATALOG=release-baseline`

## Developer build note

`jenkins/pipelines/developer_build.groovy` now exposes branch override parameters for the full service catalog, supports separate `DOMAIN_NAME` and `BACKOFFICE_DOMAIN_NAME` values for the two public UIs, and verifies that the resolved image tags already exist in the registry before Helm deploy starts.

## Recommended first validation

1. Provide `DOCKERHUB_NAMESPACE` either as a Jenkins parameter or job environment value.
2. Decide whether the job should use `jenkins/services.release-baseline.env` or `jenkins/services.env`.
3. Run `jenkins/scripts/build-images.sh` locally in the agent environment.
4. Run `helm template demo helm/yas -f helm/yas/values.yaml`.

If this delivery repo lives beside a clean cloned YAS source tree under `yas-source-upstream/`, you can usually leave `SOURCE_ROOT` blank and let the scripts auto-detect it. If only `yas-source/` exists, that remains the fallback. Set `SOURCE_ROOT` explicitly only when the source checkout lives somewhere else. If branch and commit resolution should also come from that clone, leave `SOURCE_GIT_ROOT` unset and it will follow `SOURCE_ROOT` automatically when that directory contains `.git`.

The top-level `Jenkinsfile` also supports the simplest agent setup: leave `SOURCE_ROOT` blank and it will default to `yas-source-upstream/`. If that checkout is missing, the dispatcher clones `https://github.com/nashtech-garage/yas.git` into that directory before handing control to the target pipeline.
The same source-bootstrap behavior now also exists in the direct-load pipeline files under `jenkins/pipelines/`, so even jobs that bypass the top-level dispatcher can clone or reuse the expected YAS source tree automatically.

Successful deploy and smoke-test runs now also leave runtime evidence under `work/runtime-evidence/<namespace>/<release>/`, including Helm status, pod/service snapshots, the discovered public endpoints, and copied build/push provenance such as `commit-metadata.json`, `image-digests.txt`, and related artifact indexes. The deploy and smoke-test helpers now capture that evidence on failure as well, so failed rollout or public-endpoint verification attempts still leave diagnostics behind.
The build, push, and remote-tag verification helpers now also keep their `*-metadata.json` artifacts even on mid-run failure, including completion state and the last attempted image reference.

The shared-environment deploy jobs should follow the same pattern as the developer build:

- `yas-dev-cd` deploys to `yas-dev` and then runs `jenkins/scripts/smoke-test.sh`
- `yas-staging-release` deploys to `yas-staging` and then runs `jenkins/scripts/smoke-test.sh`

`yas-dev-cd` and `yas-dev-gitops` intentionally keep `main` as the shared mutable baseline tag for `dev`, but they now also write `work/commit_sha.txt`, `work/commit_short_sha.txt`, and `work/commit-metadata.json` before the build/push step so each promotion can still be tied back to an exact source commit.
`yas-staging-release` and `yas-staging-gitops` now do the same commit-metadata capture before building release-tagged images, so a staging promotion can always be traced back to the exact source commit behind that release input.

`jenkins/scripts/cleanup-release.sh` now uses the same environment-aware namespace and release defaults as the deploy helpers, but it also guards shared environments. By default it only behaves as a developer cleanup, deletes the namespace only when `DELETE_NAMESPACE=true`, writes artifacts under `work/cleanup-evidence/<namespace>/<release>/`, refuses shared targets unless `ALLOW_SHARED_ENVIRONMENT_CLEANUP=true` is set intentionally, and still refuses deleting the whole shared namespace unless `ALLOW_SHARED_NAMESPACE_DELETE=true` is also set.

## GitOps note

`jenkins/scripts/update-manifest-repo.sh` now regenerates the full `argocd/values/*.yaml` file from the service catalog instead of editing only a few existing tag lines.
When the Jenkins checkout is detached, the same helper now also falls back from `BRANCH_NAME` to `GIT_BRANCH` before failing branch detection for the manifest push.
The regenerated GitOps overlays now also carry `image.repository`, `image.tag`, and the environment-specific ingress hosts for both `storefront` and `backoffice`, so ArgoCD does not fall back to the placeholder registry or static host defaults from `helm/yas/values.yaml`.
The same manifest-update helper now also writes `work/manifest-update-metadata.json` for every attempt, including no-op runs, with the resolved branch, commit/push state, and final action marker.

## Chart note

`helm/yas/values.yaml` is no longer just a hand-maintained baseline. It can be regenerated from `jenkins/services.env` through `scripts/generate-chart-values.ps1` or `scripts/generate-chart-values.sh`.
