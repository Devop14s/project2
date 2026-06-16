# Handover Checklist

Use this checklist when moving from the current scaffold-and-local-evidence state to a real deployment environment.

## 1. Freeze the deployment subset

- Confirm whether the first real rollout should use `release-baseline` or `full`.
- If the first rollout is still limited, keep `SERVICE_CATALOG=release-baseline`.
- Re-check [service-inventory.md](</D:/App/project2/docs/service-inventory.md>) and [service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>) before changing the subset.
- Refresh [status-report.generated.md](</D:/App/project2/work/status-report.generated.md>), [service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>), [final-report-notes.generated.md](</D:/App/project2/work/final-report-notes.generated.md>) from `work/final-report-notes.generated.md`, and [host-capabilities.generated.md](</D:/App/project2/work/host-capabilities.generated.md>) from `work/host-capabilities.generated.md` together with `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks` before handing the repo to the infrastructure owner.

## 2. Prepare the registry

- Create the real registry namespace or Docker Hub organization.
- Create Jenkins credentials for `dockerhub-creds`.
- Decide whether `DOCKERHUB_NAMESPACE` is passed as a job parameter, job environment variable, or secret text.
- Verify one manual login from the real Jenkins agent with `jenkins/scripts/docker-login.sh`.

## 3. Prepare Jenkins

- Create or update jobs for:
  - `yas-ci`
  - `yas-developer-build`
  - `yas-developer-cleanup`
  - `yas-dev-cd`
  - `yas-staging-release`
- Point jobs at the shared [Jenkinsfile](</D:/App/project2/Jenkinsfile>).
- Confirm agent tools exist:
  - `git`
  - `docker`
  - `kubectl`
  - `helm`
  - `bash`
- Set `SOURCE_ROOT` if the real YAS source checkout is not auto-detected.

## 4. Prepare the cluster

- Create or confirm the target Kubernetes cluster.
- Add Jenkins credential `kubeconfig-file`.
- Confirm `kubectl` can reach the cluster from the real Jenkins agent.
- Confirm the agent can create namespaces and install Helm releases.
- If using ArgoCD or Istio, confirm those controllers already exist before testing GitOps or mesh flows.
- If using Istio, walk through [service-mesh-test-plan.md](</D:/App/project2/docs/service-mesh-test-plan.md>) and record the actual outcome in [service-mesh-results.md](</D:/App/project2/docs/service-mesh-results.md>).

## 5. Run the first real image push

- Start with one service already strongly verified locally, preferably `product` or `storefront-bff`.
- Run a real Jenkins flow that builds and pushes the image.
- Record:
  - host or Jenkins agent that ran the flow
  - image repository
  - image tag
  - image digest
  - Jenkins console log URL or screenshot

## 6. Run the first real Helm deploy

- Use `yas-dev` or a disposable developer namespace first.
- Run the deploy pipeline with the frozen subset.
- Confirm:
  - `helm upgrade --install` succeeds
  - pods reach Ready
  - services exist
  - public UI endpoint responds
- Save runtime evidence from `work/runtime-evidence/<namespace>/<release>/`.

## 7. Run the cleanup flow

- Run `yas-developer-cleanup`.
- Confirm it removes the Helm release.
- Confirm namespace deletion behavior matches `DELETE_NAMESPACE`.
- Confirm shared-environment guards still block accidental cleanup unless explicitly enabled.

## 8. Run GitOps if required

- Run the manifest-update flow.
- Confirm `argocd/values/*.yaml` were regenerated from the chosen catalog.
- Confirm `work/manifest-update-metadata.json` exists for the run.
- In ArgoCD, confirm:
  - dev app syncs automatically
  - staging app remains manual-sync unless intentionally triggered

## 9. Handle known blockers explicitly

- If `sampledata` is still blocked by `common-library` test compilation, document whether it stays excluded.
- If `search` is still blocked by Elasticsearch Testcontainers readiness, document whether it stays excluded.
- If Keycloak-blocked services remain package-and-image-only on the host, document whether that is acceptable for the assignment scope or whether a different runtime host is required.

## 10. Prepare submission evidence

- Update [status-report.md](</D:/App/project2/docs/status-report.md>) if the real environment changes the verified state.
- Fill [final-report-template.md](</D:/App/project2/docs/final-report-template.md>) with:
  - real image names and digests
  - real namespaces and release names
  - screenshots
  - runtime endpoints
  - Jenkins logs
  - ArgoCD or mesh evidence if used

## Minimum handover package

- Real registry namespace and credential ID
- Real Jenkins job configuration
- Real kubeconfig credential
- Chosen `SERVICE_CATALOG`
- Refreshed `work/host-capabilities.generated.md`
- One successful build/push/deploy/smoke-test evidence bundle
- Updated final report draft
