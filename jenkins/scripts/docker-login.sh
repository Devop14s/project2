#!/usr/bin/env bash
set -euo pipefail

: "${DOCKER_USER:?Missing DOCKER_USER}"
: "${DOCKER_PASS:?Missing DOCKER_PASS}"

printf '%s' "$DOCKER_PASS" | docker login --username "$DOCKER_USER" --password-stdin

