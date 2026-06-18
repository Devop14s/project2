# Runtime Blockers

## Goal

Record the known runtime-dependent blockers that may still surface after infrastructure is attached, so they are not mistaken for missing scaffold work.

## Current known blockers

### `sampledata`

- Current issue:
  - `common-library` test compilation blocks the full upstream-style path
- Meaning:
  - package or image evidence may still be valid
- What to verify on the new environment:
  - exact Maven and Java versions
  - whether the same compilation failure reproduces on the Jenkins agent

### `search`

- Current issue:
  - Elasticsearch Testcontainers readiness for `ProductCdcConsumerTest`
- Meaning:
  - package or image evidence may still be valid
- What to verify on the new environment:
  - container pull ability
  - Docker daemon stability
  - resource availability

### Keycloak-blocked services

- Services:
  - `cart`
  - `customer`
  - `location`
  - `media`
  - `promotion`
  - `rating`
  - `tax`
  - `webhook`
- Current issue:
  - Keycloak Testcontainers fails to become healthy on `/health/started`
- Meaning:
  - package and image evidence may exist, but full integration paths remain host-dependent
- What to verify on the new environment:
  - Docker resource limits
  - image pull latency
  - networking and port availability
  - startup timeouts

## Decision model

- If the same blocker disappears on the real Jenkins agent:
  - treat the earlier failure as local-host noise
- If the same blocker persists:
  - decide whether the assignment scope requires that service in the accepted rollout
- If the service is out of scope for the first release:
  - keep it excluded and document the reason

## Recommended order

1. Prove one clean baseline service first:
   - `product`
   - or `storefront-bff`
2. Prove the baseline subset deploy flow.
3. Only then revisit service-specific runtime blockers.

## Pass criteria

- Blocked services are either:
  - proven on the real environment
  - or intentionally excluded with written justification

## Evidence to capture

- exact failing test name
- Jenkins console log
- container startup logs if available
- whether the failure reproduced on more than one host
