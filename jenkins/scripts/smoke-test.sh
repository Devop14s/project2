#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

DEPLOYER_ID="${DEPLOYER_ID:-dev1}"
DOMAIN_NAME="${DOMAIN_NAME:-storefront-${DEPLOYER_ID}.yas.local}"

log "Developer environment should be reachable at ${DOMAIN_NAME}:<nodePort>"
log "Replace the placeholder after the real exposed service and NodePort are confirmed."

