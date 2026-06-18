# Jenkins Runtime Setup

## Goal

Attach a real Jenkins environment to this repo so the existing pipeline definitions can run without editing repository code.

## Required repo contract

- Top-level dispatcher:
  - [Jenkinsfile](</D:/App/project2/Jenkinsfile>)
- Direct-load pipeline entrypoints:
  - [jenkins/pipelines](/abs/path/D:/App/project2/jenkins/pipelines)
- Source bootstrap parameters:
  - `SOURCE_ROOT`
  - `SOURCE_GIT_ROOT`
  - `SOURCE_REPO_URL`
  - `SOURCE_REPO_REF`

## Minimum agent toolchain

- `git`
- `bash`
- `docker`
- `kubectl`
- `helm`

## Minimum job set

- `yas-ci`
- `yas-developer-build`
- `yas-developer-cleanup`
- `yas-dev-cd`
- `yas-dev-gitops`
- `yas-staging-release`
- `yas-staging-gitops`

## Recommended configuration

- Point all jobs at the shared [Jenkinsfile](</D:/App/project2/Jenkinsfile>)
- Use `PIPELINE_TARGET` to select the flow
- Keep `SERVICE_CATALOG=release-baseline` for the first live rollout unless the assignment explicitly needs full scope

## Source bootstrap behavior

Default behavior already implemented in repo:

- clone source into `yas-source-upstream/`
- use source repo `https://github.com/nashtech-garage/yas.git`
- use source ref `main`

Override only if required:

- `SOURCE_ROOT` if the workspace path must differ
- `SOURCE_GIT_ROOT` if commit resolution must differ from build context
- `SOURCE_REPO_URL` if a mirror or private fork is required
- `SOURCE_REPO_REF` if a tag, release branch, or alternate ref is required

## First-time setup steps

1. Create the Jenkins jobs.
2. Bind `dockerhub-creds`.
3. Bind `kubeconfig-file`.
4. Set `DOCKERHUB_NAMESPACE`.
5. Leave `SOURCE_ROOT` blank for the first attempt unless the agent workspace requires a custom path.
6. Run the readiness gate:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\agent-readiness.ps1
```

```bash
sh scripts/agent-readiness.sh
```

7. Run `yas-ci`.
8. Run `yas-developer-build` or `yas-dev-cd`.

## Pass criteria

- The first run can start with only the delivery repo checked out
- `yas-source-upstream/` is bootstrapped automatically
- The pipeline reaches source clone, docker login, and build stages without repo edits
- Expected `work/*.json` and `work/*.txt` artifacts are created

## Common failures

- Agent lacks `bash`
- Agent lacks Docker daemon access
- Source bootstrap path is blocked by workspace permissions
- Wrong `SOURCE_REPO_URL` or private repo auth issue
- Job uses direct-load pipeline but not the shared dispatcher and misses required environment setup

## Evidence to capture

- Job names
- Jenkins parameters used
- First successful bootstrap log
- First successful `work/commit-metadata.json`
- First successful `work/image-digests.txt`
