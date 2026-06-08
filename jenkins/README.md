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

- `DOCKERHUB_NAMESPACE`

## Service catalog format

`jenkins/services.env` uses this layout:

`service|path|dockerfile|port|expose|nodePort|workloadType`

Example:

`storefront|storefront|storefront/Dockerfile|3000|true|32080|ui`

## Recommended first validation

1. Replace `replace-me` in `Jenkinsfile`.
2. Update `jenkins/services.env` to match the real repo.
3. Run `jenkins/scripts/build-images.sh` locally in the agent environment.
4. Run `helm template demo helm/yas -f helm/yas/values.yaml`.
