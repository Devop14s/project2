# Failure Triage Checklist

Use this checklist after the first failed real Jenkins or cluster run.

## Goal

Classify a failure quickly as:

- `registry/auth`
- `source bootstrap`
- `agent tooling`
- `cluster access`
- `deploy/runtime`
- `repo issue`

## 1. Source Bootstrap

- Check whether `yas-source-upstream/` was created.
- Check whether `SOURCE_REPO_URL` and `SOURCE_REPO_REF` resolved to the expected remote and ref.
- Check whether `SOURCE_ROOT` and `SOURCE_GIT_ROOT` point to real paths on the agent.
- If the pipeline failed before `yas-source-upstream/` existed, classify it as `source bootstrap` or `agent tooling`, not `repo issue`.

## 2. Registry And Auth

- Check `dockerhub-creds` binding in Jenkins.
- Check `DOCKERHUB_NAMESPACE`.
- Check `jenkins/scripts/docker-login.sh`.
- Check whether the agent can run `docker version`.
- If login fails before any service build starts, classify it as `registry/auth`.
- If login succeeds but the first backend or BFF image fails on `COPY target/*.jar`, classify it first as a source-artifact/runtime contract issue, not as a registry failure.

## 3. Agent Tooling

- Run [scripts/agent-readiness.ps1](/abs/path/D:/App/project2/scripts/agent-readiness.ps1) or `sh scripts/agent-readiness.sh`.
- Treat `scripts/agent-readiness.ps1` as the default readiness gate on Windows agents.
- Confirm:
  - `git`
  - `bash`
  - `docker`
  - `kubectl`
  - `helm`
- If required readiness checks fail, classify it as `agent tooling`.
- Also check for controller-level runtime blockers that can stop the queue before the build script even starts:
  - built-in node is temporarily offline
  - disk monitor forced the node offline because `/var/jenkins_home` dropped below the safety threshold

## 4. Cluster Access

- Check `kubeconfig-file`.
- Check `kubectl get ns`.
- Check `helm version`.
- Check namespace create permission.
- If the pipeline reaches cluster commands but cannot talk to the cluster, classify it as `cluster access`.

## 5. Deploy Or Smoke-Test Runtime

- Inspect `work/runtime-evidence/<namespace>/<release>/`.
- Check Helm release status.
- Check pods, services, ingress, and discovered endpoints.
- If the image was built and pushed correctly but pods never become ready, classify it as `deploy/runtime`.

## 6. GitOps

- Check `work/manifest-update-metadata.json`.
- Check whether `argocd/values/*.yaml` was regenerated.
- Check ArgoCD sync policy and target repo permissions.
- If manifest generation worked but ArgoCD sync did not, classify it as `cluster access` or `deploy/runtime`, not automatically `repo issue`.

## 7. Known Service-Specific Blockers

- `sampledata`: `common-library` test compilation
- `search`: Elasticsearch Testcontainers readiness
- `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, `webhook`: Keycloak Testcontainers readiness

If one of these reappears unchanged on a new host, classify it first as `deploy/runtime` or `environment-specific test blocker`, not immediately as repo logic drift.

## 8. Escalate To Repo Issue Only If

- a script path is wrong
- a pipeline variable contract is inconsistent
- source bootstrap parameters are ignored
- generated values are structurally wrong
- runtime evidence is missing despite the documented success path
- a flow needs code edits in this repository before the environment-specific failure can even be tested

Recent real-run examples that are not repo issues by themselves:

- Jenkins controller offline because free disk dropped below the node monitor threshold
- Jenkins prebuilt source tree owned by `root`, causing Git `detected dubious ownership`
- Real CI build requires `SOURCE_ROOT` to point at a prebuilt source tree because backend Dockerfiles expect `target/*.jar` artifacts

## Decision

- `INFRA FIX FIRST`: source bootstrap, registry, agent, cluster, or runtime problem
- `RETRY ON CLEAN HOST`: host-specific daemon or Testcontainers instability
- `REPO FIX REQUIRED`: repository code or configuration must change before retesting
