# Jenkins Bootstrap Runbook

Use this runbook the first time a real Jenkins environment is attached to this repo.

## Goal

Bring a Jenkins agent from empty workspace to the first successful YAS build or deploy flow without editing repository code.

## 1. Create The Jobs

- Create or update these jobs:
  - `yas-ci`
  - `yas-developer-build`
  - `yas-developer-cleanup`
  - `yas-dev-cd`
  - `yas-dev-gitops`
  - `yas-staging-release`
  - `yas-staging-gitops`
- Point each job to [Jenkinsfile](/abs/path/D:/App/project2/Jenkinsfile) unless you intentionally need a direct-load pipeline.
- If direct-load is required, point the job at the matching file under [jenkins/pipelines](/abs/path/D:/App/project2/jenkins/pipelines).

## 2. Prepare The Agent

- Confirm the agent has:
  - `git`
  - `bash`
  - `docker`
  - `kubectl`
  - `helm`
- Run the readiness check before the first real pipeline:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\agent-readiness.ps1
```

```bash
sh scripts/agent-readiness.sh
```

- If the required checks fail, stop and fix the agent before trying a delivery flow.

## 3. Configure Credentials

- Add Jenkins username/password credential `dockerhub-creds`.
- Add Jenkins secret-file credential `kubeconfig-file`.
- Decide whether `DOCKERHUB_NAMESPACE` is supplied:
  - as a job parameter
  - as a job environment variable
  - from secret text expanded into the environment

## 4. Configure Source Bootstrap

- Default behavior:
  - clone YAS into `yas-source-upstream/`
  - source remote `https://github.com/nashtech-garage/yas.git`
  - source ref `main`
- Override only when needed:
  - `SOURCE_ROOT`
  - `SOURCE_GIT_ROOT`
  - `SOURCE_REPO_URL`
  - `SOURCE_REPO_REF`
- Expected result:
  - first run can start with only the delivery repo checked out
  - the pipeline bootstraps `yas-source-upstream/` automatically

## 5. Pick The First Flow

- Recommended first real flow: `yas-ci`
- Recommended first service target:
  - `product`
  - or `storefront-bff`
- Recommended first catalog:
  - `release-baseline`

## 6. Expected Evidence

- CI-like flows should produce:
  - `work/commit_sha.txt`
  - `work/commit_short_sha.txt`
  - `work/commit-metadata.json`
  - `work/built-image-list.txt`
  - `work/image-list.txt`
  - `work/image-digests.txt`
  - `work/image-metadata.json`
- Deploy flows should additionally produce:
  - `work/runtime-evidence/<namespace>/<release>/`
- GitOps flows should additionally produce:
  - `work/manifest-update-metadata.json`

## 7. First-Pass Sequence

1. Run `scripts/agent-readiness.ps1` or `scripts/agent-readiness.sh`.
2. Run `yas-ci` with a known-good subset.
3. Confirm registry login, build, and push.
4. Run `yas-developer-build` or `yas-dev-cd`.
5. Confirm deploy and smoke-test evidence.
6. Run `yas-developer-cleanup`.

## 8. Stop Conditions

- Stop immediately if source bootstrap fails.
- Stop immediately if `docker login` fails.
- Stop immediately if `kubectl get ns` or `helm version` fails on the real agent.
- Stop immediately if the first real run requires editing pipeline code; that should be treated as a repo issue, not normal bootstrap work.

## 9. After The First Successful Run

- Refresh:
  - [work/status-report.generated.md](</D:/App/project2/work/status-report.generated.md>)
  - [work/service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>)
  - [work/final-report-notes.generated.md](</D:/App/project2/work/final-report-notes.generated.md>)
  - [work/host-capabilities.generated.md](</D:/App/project2/work/host-capabilities.generated.md>)
- Evaluate the environment using [acceptance-checklist.md](</D:/App/project2/docs/acceptance-checklist.md>).
