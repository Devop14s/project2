# CI Flow

## Goal

Build and push service images on every branch push. The image tag must equal the latest commit SHA for that branch.

## Pipeline stages

1. Checkout source.
2. Resolve `GIT_COMMIT` and `SHORT_SHA`.
3. Authenticate to Docker Hub.
4. Build all required deployable services.
5. Push images.
6. Publish build metadata into `work/`.

## Required variables

- `DOCKERHUB_NAMESPACE`
- `DOCKER_USER`
- `DOCKER_PASS`

## Output artifacts

- `work/commit_sha.txt`
- `work/commit_short_sha.txt`
- `work/image-list.txt`
- `work/image-metadata.json`

