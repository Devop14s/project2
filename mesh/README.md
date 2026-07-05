# Service Mesh Scaffold

This directory contains Istio-oriented manifests that can be adapted once the real YAS service names and paths are confirmed.

The current chart now creates one `ServiceAccount` per workload named after the service key, so the `AuthorizationPolicy` principals in this directory line up with the deployed pods once the app is installed in `yas-dev`.

## Files

- `peer-authentication.yaml`
- `destination-rule.yaml`
- `virtual-service-retry.yaml`
- `authorization-policy.yaml`
- `kiali-access.md`
- `../infra/infra-destination-rules.yaml`

## Apply order

1. Deploy the YAS workloads into `yas-dev`.
2. Apply `peer-authentication.yaml`.
3. Apply `destination-rule.yaml`.
4. Apply `../infra/infra-destination-rules.yaml` for PostgreSQL, Kafka, and Elasticsearch because those static infra pods do not use Istio mTLS.
5. Apply `authorization-policy.yaml`.
6. Apply `virtual-service-retry.yaml`.

## Supporting docs

- [service-mesh-test-plan.md](</D:/App/project2/docs/service-mesh-test-plan.md>) describes the real runtime checks to run once Istio is installed on a cluster.
- [service-mesh-results.md](</D:/App/project2/docs/service-mesh-results.md>) is the place to record what was actually executed versus what remains scaffold-only.
