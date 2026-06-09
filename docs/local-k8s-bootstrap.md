# Local Kubernetes Bootstrap

## Minimum toolset

- Docker
- `kubectl`
- `helm`
- Jenkins

## Minimal validation

1. Bring up a local cluster with `minikube`, `k3s`, or equivalent.
2. Verify `kubectl get nodes`.
3. Verify the Jenkins agent can run `kubectl version --client` and `helm version`.
4. Validate the chart with `helm template`.
5. Deploy one service first before expanding to the full system.

