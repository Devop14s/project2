#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
TAG="${RELEASE_VERSION:-$(git rev-parse HEAD)}"

iter_services | while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  [[ -f "$dockerfile" ]] || fail "Dockerfile not found for ${service}: ${dockerfile}"
  log "Building ${service} with tag ${TAG}"
  docker build \
    -t "$(image_repo "$service"):${TAG}" \
    -f "$dockerfile" \
    "$path"
done
