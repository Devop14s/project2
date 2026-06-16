#!/usr/bin/env sh
set -eu

readme_file="${1:-argocd/README.md}"
readme_text="$(cat "$readme_file")"

for token in \
  '`app-dev.yaml`' \
  '`app-staging.yaml`' \
  '`argocd/values/*.yaml`' \
  '`validate-argocd-apps`' \
  '`main` target revision' \
  '`CreateNamespace=true`' \
  '`SERVICE_CATALOG=release-baseline`' \
  '`work/manifest-update-metadata.json`' \
  '`jenkins/services.release-baseline.env`' \
  '`jenkins/services.env`'
do
  printf '%s' "$readme_text" | grep -F -q "$token" || {
    printf 'argocd/README.md is missing required token %s.\n' "$token" >&2
    exit 1
  }
done

printf 'argocd/README.md is aligned with the current ArgoCD manifest, overlay, and manifest-update metadata contracts.\n'
