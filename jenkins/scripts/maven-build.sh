#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

# Collect backend module paths from the service catalog (skip ui workload type)
backend_modules=""
while IFS='|' read -r service path dockerfile port expose node_port workload_type; do
  [[ "$workload_type" == "ui" ]] && continue
  [[ -z "$path" ]] && continue
  backend_modules="${backend_modules:+${backend_modules},}${path}"
done < <(iter_services)

if [[ -z "$backend_modules" ]]; then
  log "No backend services found in catalog — skipping Maven build"
  exit 0
fi

log "Backend modules to compile: common-library,${backend_modules}"

MVN_CMD="mvn"
if [[ -f "${SOURCE_ROOT}/mvnw" ]]; then
  MVN_CMD="${SOURCE_ROOT}/mvnw"
fi

log "Running Maven package in ${SOURCE_ROOT}"
"$MVN_CMD" -f "${SOURCE_ROOT}/pom.xml" \
  package \
  -pl "common-library,${backend_modules}" \
  -am \
  -Dmaven.test.skip=true \
  -Djava.version=21 \
  -Dmaven.compiler.source=21 \
  -Dmaven.compiler.target=21 \
  --no-transfer-progress \
  -q

log "Maven build complete"
