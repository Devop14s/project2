#!/usr/bin/env sh
set -eu

readme_file="${1:-jenkins/README.md}"
readme_text="$(cat "$readme_file")"

for token in \
  '`yas-ci`' \
  '`yas-developer-build`' \
  '`yas-developer-cleanup`' \
  '`yas-dev-cd`' \
  '`yas-staging-release`' \
  '`DOCKERHUB_NAMESPACE`' \
  '`SERVICE_CATALOG`' \
  '`SOURCE_ROOT`' \
  '`SOURCE_GIT_ROOT`' \
  '`jenkins/services.release-baseline.env`' \
  '`jenkins/services.env`' \
  '`work/runtime-evidence/<namespace>/<release>/`' \
  '`work/manifest-update-metadata.json`' \
  '`ALLOW_SHARED_ENVIRONMENT_CLEANUP=true`' \
  '`ALLOW_SHARED_NAMESPACE_DELETE=true`'
do
  printf '%s' "$readme_text" | grep -F -q "$token" || {
    printf 'jenkins/README.md is missing required token %s.\n' "$token" >&2
    exit 1
  }
done

printf 'jenkins/README.md is aligned with the current Jenkins job, catalog, and runtime-evidence contracts.\n'
