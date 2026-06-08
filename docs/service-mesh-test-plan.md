# Service Mesh Test Plan

## Test 1: mTLS strict mode

1. Label the target namespace for sidecar injection.
2. Redeploy workloads.
3. Confirm each pod has the app container plus the Istio proxy.
4. Apply `mesh/peer-authentication.yaml`.
5. Verify service-to-service traffic still works.

## Test 2: Retry on HTTP 500

1. Apply `mesh/destination-rule.yaml`.
2. Apply `mesh/virtual-service-retry.yaml`.
3. Trigger a request path that can return `500`.
4. Inspect logs for retry attempts.

## Test 3: Allow and deny policy

1. Apply `mesh/authorization-policy.yaml`.
2. `kubectl exec` from the allowed source pod and confirm success.
3. `kubectl exec` from a disallowed source pod and confirm denial.
4. Save the `curl -v` output and pod logs.

