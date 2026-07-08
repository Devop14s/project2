#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

ENVIRONMENT="${ENVIRONMENT:-developer}"
DEPLOYER_ID="${DEPLOYER_ID:-dev1}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-yas-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgres-0}"

if [[ "$ENVIRONMENT" != "developer" ]]; then
  log "Skipping database provisioning for environment: ${ENVIRONMENT}"
  exit 0
fi

DB_SERVICES=(cart order customer inventory tax media search product)
DB_SUFFIX="$(printf '%s' "$DEPLOYER_ID" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_')"

for service in "${DB_SERVICES[@]}"; do
  db_name="${service}_${DB_SUFFIX}"
  exists="$(kubectl exec -n "$POSTGRES_NAMESPACE" "$POSTGRES_POD" -- psql -U admin -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${db_name}'")"

  if [[ "$exists" == "1" ]]; then
    log "Database ${db_name} already exists"
  else
    log "Creating database ${db_name}"
    kubectl exec -n "$POSTGRES_NAMESPACE" "$POSTGRES_POD" -- psql -U admin -d postgres -c "CREATE DATABASE ${db_name};"
  fi
done
