# Registry Setup

## Goal

Provide a real image registry target that the Jenkins flows can log into, push to, and verify against without any repository code changes.

## Required repo contract

- Jenkins credential id: `dockerhub-creds`
- Environment or parameter: `DOCKERHUB_NAMESPACE`
- Repository naming pattern: `<namespace>/yas-<service>`

## Inputs you must decide

- Registry host:
  - Docker Hub
  - GHCR
  - private OCI registry
- Namespace or organization:
  - for example `docker.io/your-org`
  - or `ghcr.io/your-org`
- Whether public pull access is required
- Whether the same registry is used for both dev and staging

## Setup steps

1. Create the registry namespace or organization.
2. Confirm the service account or robot user can push images.
3. Store the username/password in Jenkins as credential `dockerhub-creds`.
4. Decide how `DOCKERHUB_NAMESPACE` is supplied:
   - Jenkins parameter
   - Jenkins global environment
   - folder-level environment
5. Pick one repository name and verify it matches the repo contract:
   - expected: `your-namespace/yas-product`
6. From the Jenkins agent, run a manual login:

```bash
export DOCKER_USER='<username>'
export DOCKER_PASS='<password>'
jenkins/scripts/docker-login.sh
```

## Pass criteria

- `docker login` succeeds on the real Jenkins agent
- The chosen namespace is visible after login
- Pushing a test image to `yas-product` works
- Pulling the same pushed image from a second environment works

## Common failures

- Wrong credential id:
  - Jenkins cannot bind `dockerhub-creds`
- Wrong namespace:
  - build succeeds but push fails with repository not found
- Wrong registry host in namespace:
  - build targets Docker Hub while the real target is GHCR or private OCI
- Agent Docker daemon unavailable:
  - `docker version` fails before login logic is even reached

## Evidence to capture

- Jenkins credential id used
- Registry namespace
- One successful login log
- One pushed image reference
- One image digest from `work/image-digests.txt`
