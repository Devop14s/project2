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
- `SOURCE_ROOT` when the YAS source checkout is not at the workspace root
- `SOURCE_GIT_ROOT` when commit and branch resolution should use a different Git checkout

## Output artifacts

- `work/commit_sha.txt`
- `work/commit_short_sha.txt`
- `work/commit-metadata.json`
- `work/built-image-list.txt`
- `work/image-list.txt`
- `work/image-digests.txt`
- `work/image-metadata.json`

The build, push, and remote-tag verification helpers now preserve their metadata files even when a run fails mid-stream, so the final attempted service and image reference remain available for debugging.

## Source-of-truth note

When this delivery repo is separate from the YAS source repo, the CI scripts resolve Docker build contexts from `SOURCE_ROOT` and derive default commit-SHA tags from `SOURCE_GIT_ROOT`.

