# Final Acceptance Checklist

Use this checklist when the real Jenkins, registry, and Kubernetes environment are ready. Each line should end in a clear `PASS`, `FAIL`, or `N/A`.

If any required line fails, assume the repo is not yet fully accepted and record whether the gap is:

- infrastructure-only
- runtime-only
- repo/code issue

## 1. Agent Bootstrap

- `PASS` / `FAIL`: Jenkins agent can check out this delivery repo successfully.
- `PASS` / `FAIL`: Jenkins agent has `git`, `bash`, `docker`, `kubectl`, and `helm` on `PATH`.
- `PASS` / `FAIL`: Jenkins agent can run `jenkins/scripts/docker-login.sh`.
- `PASS` / `FAIL`: Jenkins agent can run `kubectl version --client`.
- `PASS` / `FAIL`: Jenkins agent can run `helm version`.
- `PASS` / `FAIL`: Top-level [Jenkinsfile](</D:/App/project2/Jenkinsfile>) can bootstrap the YAS source checkout into `yas-source-upstream/` automatically when the folder is missing.
- `PASS` / `FAIL`: Direct-load pipeline entrypoints under [jenkins/pipelines](/abs/path/D:/App/project2/jenkins/pipelines) can also bootstrap `yas-source-upstream/` automatically when the folder is missing.
- `PASS` / `FAIL`: If a mirror or private fork is required, `SOURCE_REPO_URL` and `SOURCE_REPO_REF` work without code edits.

## 2. Registry Wiring

- `PASS` / `FAIL`: Jenkins credential `dockerhub-creds` exists and is readable by the job.
- `PASS` / `FAIL`: `DOCKERHUB_NAMESPACE` resolves correctly in the chosen job.
- `PASS` / `FAIL`: One manual registry login from the real agent succeeds.
- `PASS` / `FAIL`: Built image names match the expected `yas-<service>` repository naming.
- `PASS` / `FAIL`: Pushed image tags match the intended commit SHA or release version strategy.

## 3. Cluster Wiring

- `PASS` / `FAIL`: Jenkins credential `kubeconfig-file` exists and is readable by the job.
- `PASS` / `FAIL`: `kubectl get ns` succeeds from the real agent.
- `PASS` / `FAIL`: `helm upgrade --install` is allowed in the target namespace.
- `PASS` / `FAIL`: The agent can create or update namespace, deployment, service, and ingress or equivalent service exposure.
- `PASS` / `FAIL`: If GitOps is required, ArgoCD is already reachable and pointed at the correct repo.
- `PASS` / `FAIL`: If service mesh is required, Istio or the chosen mesh already exists before mesh validation starts.

## 4. CI Build Flow

- `PASS` / `FAIL`: `yas-ci` or equivalent direct-load CI pipeline completes successfully.
- `PASS` / `FAIL`: `work/commit_sha.txt`, `work/commit_short_sha.txt`, and `work/commit-metadata.json` are produced.
- `PASS` / `FAIL`: `work/built-image-list.txt`, `work/image-list.txt`, `work/image-digests.txt`, and `work/image-metadata.json` are produced.
- `PASS` / `FAIL`: At least one baseline service such as `product` or `storefront-bff` builds and pushes successfully.
- `PASS` / `FAIL`: No code change in this repo was required to make the first real CI build work.

## 5. Developer Build Flow

- `PASS` / `FAIL`: `yas-developer-build` or equivalent direct-load pipeline completes successfully.
- `PASS` / `FAIL`: Branch override parameters resolve into `work/branch-tags.env` and `work/branch-tag-metadata.json`.
- `PASS` / `FAIL`: `jenkins/scripts/verify-image-tags.sh` can verify prebuilt tags before deploy starts.
- `PASS` / `FAIL`: Developer namespace and release naming follow the expected `DEPLOYER_ID` contract.
- `PASS` / `FAIL`: `work/runtime-evidence/<namespace>/<release>/` is created with runtime diagnostics and copied artifacts.
- `PASS` / `FAIL`: No code change in this repo was required to make the first real developer-build flow work.

## 6. Shared Dev Or Staging Deploy Flow

- `PASS` / `FAIL`: `yas-dev-cd`, `yas-dev-gitops`, `yas-staging-release`, or `yas-staging-gitops` can run successfully in the chosen environment.
- `PASS` / `FAIL`: Generated values use the selected `SERVICE_CATALOG` without manual editing.
- `PASS` / `FAIL`: Release name and namespace defaults match the expected environment contract.
- `PASS` / `FAIL`: Public UI endpoints for `storefront` and `backoffice` respond after deploy.
- `PASS` / `FAIL`: Runtime evidence is preserved even when deploy or smoke-test fails.
- `PASS` / `FAIL`: No code change in this repo was required to make the first real shared-environment deploy work.

## 7. Cleanup Flow

- `PASS` / `FAIL`: `yas-developer-cleanup` removes the expected Helm release.
- `PASS` / `FAIL`: Namespace deletion behavior follows `DELETE_NAMESPACE`.
- `PASS` / `FAIL`: Shared-environment protection blocks accidental cleanup unless `ALLOW_SHARED_ENVIRONMENT_CLEANUP=true`.
- `PASS` / `FAIL`: Shared namespace deletion remains blocked unless `ALLOW_SHARED_NAMESPACE_DELETE=true`.
- `PASS` / `FAIL`: Cleanup evidence is written under `work/cleanup-evidence/<namespace>/<release>/`.

## 8. GitOps Flow

- `PASS` / `FAIL`: `jenkins/scripts/update-manifest-repo.sh` updates `argocd/values/dev-values.yaml` or `argocd/values/staging-values.yaml` without manual fixes.
- `PASS` / `FAIL`: `work/manifest-update-metadata.json` is produced for the run.
- `PASS` / `FAIL`: ArgoCD sync behavior matches expectation: dev automated, staging manual unless intentionally changed.
- `PASS` / `FAIL`: No code change in this repo was required to make the first real GitOps flow work.

## 9. Service Verification Scope

- `PASS` / `FAIL`: The selected rollout subset matches `jenkins/services.release-baseline.env` or an intentionally chosen `full` catalog.
- `PASS` / `FAIL`: Services already locally verified as strong candidates still build and deploy in the real environment.
- `PASS` / `FAIL`: Any excluded service is excluded by a conscious scope decision, not by an accidental repo gap.
- `PASS` / `FAIL`: Known blockers for `sampledata`, `search`, or Keycloak-blocked services are documented as infra/runtime issues or explicitly accepted scope exclusions.

## 10. Final Evidence And Reporting

- `PASS` / `FAIL`: `scripts\refresh-evidence.ps1 -SkipCommandChecks` still succeeds after infrastructure wiring.
- `PASS` / `FAIL`: [work/status-report.generated.md](</D:/App/project2/work/status-report.generated.md>), [work/service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>), [work/final-report-notes.generated.md](</D:/App/project2/work/final-report-notes.generated.md>), and [work/host-capabilities.generated.md](</D:/App/project2/work/host-capabilities.generated.md>) are refreshed.
- `PASS` / `FAIL`: Jenkins logs, runtime evidence, image digests, and endpoint proof are sufficient to fill [final-report-template.md](</D:/App/project2/docs/final-report-template.md>) without guessing.
- `PASS` / `FAIL`: No repo code change was required during evidence capture for the final accepted run.

## Decision Rule

- `ACCEPT`: all required items are `PASS`, and any `N/A` item is outside the agreed assignment scope.
- `REJECT`: any required item is `FAIL`.
- `INFRA BLOCKED`: only infrastructure or environment items fail, and no repo/code issue was found.
- `REPO FIX REQUIRED`: any failure requires editing repository code, scripts, pipeline definitions, chart logic, or docs to proceed.
