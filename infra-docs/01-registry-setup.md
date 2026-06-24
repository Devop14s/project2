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

## Verified status on June 24, 2026

- Registry step was verified successfully on the project-specific Jenkins instance at `http://20.2.66.240:8081/`.
- Jenkins job used:
  - `project2-yas-ci`
- Verified registry namespace:
  - `luongtrz`
- Verified credential contract:
  - Jenkins credential id `dockerhub-creds` was bound successfully during the real run.
- Verified result:
  - CI build `#12` completed with `SUCCESS`.
  - Baseline images were built and pushed successfully for:
    - `storefront`
    - `backoffice`
    - `storefront-bff`
    - `backoffice-bff`
    - `product`
    - `cart`
    - `customer`
    - `rating`
    - `location`
    - `order`
    - `inventory`
    - `tax`

## Important runtime note

- The first successful real CI run on this Jenkins host used:
  - `SOURCE_ROOT=/var/jenkins_home/prebuilt/yas-source-upstream`
  - `SOURCE_GIT_ROOT=/var/jenkins_home/prebuilt/yas-source-upstream`
- That source tree had already been prebuilt for the baseline Java services so their `target/*.jar` artifacts existed before `jenkins/scripts/build-images.sh` started.
- This means the registry wiring is now verified end to end, but it is verified through a prebuilt-source runtime contract rather than through a clean workspace that compiles all backend artifacts inside the CI pipeline itself.

## Common failures

- Wrong credential id:
  - Jenkins cannot bind `dockerhub-creds`
- Wrong namespace:
  - build succeeds but push fails with repository not found
- Wrong registry host in namespace:
  - build targets Docker Hub while the real target is GHCR or private OCI
- Agent Docker daemon unavailable:
  - `docker version` fails before login logic is even reached
- Source tree is clean but backend artifacts are missing:
  - backend and BFF Dockerfiles expect prebuilt `target/*.jar` artifacts, so image build fails unless the source tree was packaged earlier or the pipeline is extended to build those artifacts first
- Jenkins source tree ownership mismatch:
  - Git can fail with `detected dubious ownership` if the prebuilt source checkout is not owned by the `jenkins` user or not marked as a safe Git directory
- Jenkins node goes offline due to low disk:
  - the controller can stay offline until Docker build cache or workspace data is cleaned and the node is brought back online

## Evidence to capture

- Jenkins credential id used
- Registry namespace
- One successful login log
- One pushed image reference
- One image digest from `work/image-digests.txt`
- Successful real-run example:
  - `project2-yas-ci #12` on June 24, 2026
