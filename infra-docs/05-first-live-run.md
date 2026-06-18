# First Live Run

## Goal

Run the first real end-to-end infrastructure-backed flow in the safest order, using the repo exactly as it exists now.

## Recommended order

1. Run the agent readiness gate.
2. Run `yas-ci` with `SERVICE_CATALOG=release-baseline`.
3. Confirm one image push for a known-good service such as `product`.
4. Run `yas-developer-build` or `yas-dev-cd`.
5. Confirm deploy and smoke-test evidence.
6. Run `yas-developer-cleanup`.
7. Evaluate with [docs/acceptance-checklist.md](</D:/App/project2/docs/acceptance-checklist.md>).

## Concrete first-pass values

- `PIPELINE_TARGET=ci`
- `SERVICE_CATALOG=release-baseline`
- `DOCKERHUB_NAMESPACE=<real namespace>`
- `SOURCE_ROOT=` blank
- `SOURCE_GIT_ROOT=` blank
- `SOURCE_REPO_URL=https://github.com/nashtech-garage/yas.git`
- `SOURCE_REPO_REF=main`

## Expected successful artifacts

From CI:

- `work/commit_sha.txt`
- `work/commit_short_sha.txt`
- `work/commit-metadata.json`
- `work/built-image-list.txt`
- `work/image-list.txt`
- `work/image-digests.txt`
- `work/image-metadata.json`

From deploy:

- `work/runtime-evidence/<namespace>/<release>/`

From GitOps if used:

- `work/manifest-update-metadata.json`

## Stop immediately if

- `scripts/agent-readiness.ps1` or `sh scripts/agent-readiness.sh` fails required checks
- source bootstrap does not create `yas-source-upstream/`
- `docker login` fails
- `kubectl get ns` fails
- the first real run requires editing repository code before infra-only issues are resolved

## After a failed run

Use:

- [docs/failure-triage.md](</D:/App/project2/docs/failure-triage.md>)
- [docs/acceptance-checklist.md](</D:/App/project2/docs/acceptance-checklist.md>)

## After a successful run

Refresh:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks
```

Then capture:

- Jenkins log URL
- image digest
- namespace
- release name
- public endpoint evidence
- any runtime-evidence bundle copied from `work/runtime-evidence/<namespace>/<release>/`
