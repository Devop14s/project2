#!/usr/bin/env sh
set -eu

docs_root="${1:-docs}"

assert_contains_all() {
  file_path="$1"
  shift
  text="$(cat "$file_path")"

  for token in "$@"; do
    printf '%s' "$text" | grep -F -q "$token" || {
      printf '%s is missing required token %s.\n' "$file_path" "$token" >&2
      exit 1
    }
  done
}

assert_contains_all "${docs_root}/ci-flow.md" \
  'DOCKERHUB_NAMESPACE' \
  'SOURCE_ROOT' \
  'SOURCE_GIT_ROOT' \
  'work/commit-metadata.json' \
  'work/image-digests.txt'

assert_contains_all "${docs_root}/deployment-topology.md" \
  '`yas-dev`' \
  '`yas-staging`' \
  '`yas-user-<developer-id>`' \
  '`NodePort`' \
  '`storefront-dev.yas.local`' \
  '`storefront-staging.yas.local`'

assert_contains_all "${docs_root}/dev-environment.md" \
  '`main`' \
  '`yas-dev`' \
  '`work/commit_sha.txt`' \
  '`work/commit_short_sha.txt`' \
  '`work/commit-metadata.json`'

assert_contains_all "${docs_root}/developer-build.md" \
  '`DEPLOYER_ID`' \
  '`SERVICE_CATALOG`' \
  '`work/verified-image-list.txt`' \
  '`work/branch-tag-metadata.json`' \
  '`work/runtime-evidence/<namespace>/<release>/`' \
  '`storefront`' \
  '`backoffice`'

assert_contains_all "${docs_root}/developer-cleanup.md" \
  '`DELETE_NAMESPACE`' \
  '`ALLOW_SHARED_ENVIRONMENT_CLEANUP`' \
  '`ALLOW_SHARED_NAMESPACE_DELETE`' \
  '`work/cleanup-evidence/<namespace>/<release>/`'

assert_contains_all "${docs_root}/local-dry-run.md" \
  'scripts\developer-build-dry-run.ps1' \
  'scripts/developer-build-dry-run.sh' \
  'scripts\selftest.ps1' \
  'scripts/selftest.sh' \
  'scripts\preflight.ps1 -SkipCommandChecks' \
  'scripts/preflight.sh --skip-command-checks' \
  'scripts\refresh-evidence.ps1 -SkipCommandChecks' \
  'work/final-report-notes.generated.md' \
  'work/host-capabilities.generated.md'

assert_contains_all "${docs_root}/local-k8s-bootstrap.md" \
  '`kubectl`' \
  '`helm`' \
  'Jenkins' \
  '`helm template`'

assert_contains_all "${docs_root}/staging-release.md" \
  '`yas-staging`' \
  '`work/image-digests.txt`' \
  '`work/runtime-evidence/yas-staging/yas-staging/`' \
  '`work/commit-metadata.json`'

assert_contains_all "${docs_root}/argocd-flow.md" \
  '`argocd/app-dev.yaml`' \
  '`argocd/app-staging.yaml`' \
  '`argocd/values/dev-values.yaml`' \
  '`argocd/values/staging-values.yaml`' \
  '`jenkins/services.release-baseline.env`' \
  '`jenkins/services.env`' \
  '`work/manifest-update-metadata.json`'

printf 'Operational runbooks and topology docs are aligned with the current pipeline, runtime-evidence, and GitOps contracts.\n'
