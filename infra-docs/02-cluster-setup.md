# Cluster Setup

## Goal

Prepare a real Kubernetes environment so the existing Helm and runtime-evidence flows can deploy without repo changes.

## Required repo contract

- Jenkins credential id: `kubeconfig-file`
- Jenkins agent can run:
  - `kubectl`
  - `helm`
- Expected namespaces:
  - `yas-dev`
  - `yas-staging`
  - `yas-user-<developer-id>`

## Inputs you must decide

- Cluster type:
  - local lab
  - managed Kubernetes
  - on-prem cluster
- Ingress strategy:
  - Ingress controller
  - NodePort
  - LoadBalancer
- Whether ArgoCD is required
- Whether Istio or another mesh is required

## Setup steps

1. Obtain a working kubeconfig for the target cluster.
2. Store it in Jenkins as secret-file credential `kubeconfig-file`.
3. Confirm the Jenkins agent can reach the API server:

```bash
kubectl get ns
kubectl version --client
helm version
```

4. Confirm permissions for:
   - namespace create
   - deployment create/update
   - service create/update
   - ingress create/update or equivalent exposure
5. Create or confirm shared namespaces if your governance requires them ahead of time:
   - `yas-dev`
   - `yas-staging`
6. Confirm the cluster has any required platform controllers:
   - ingress controller
   - ArgoCD
   - Istio or other mesh

## Pass criteria

- `kubectl get ns` succeeds from the Jenkins agent
- `helm version` succeeds from the Jenkins agent
- A disposable namespace can be created
- A disposable Helm release can be installed and removed

## Common failures

- Kubeconfig exists but is bound to the wrong cluster
- Agent can talk to cluster but cannot create namespace
- Helm works locally but the Jenkins agent cannot find `helm`
- Ingress object is created but no controller exists to realize it
- NodePort is exposed but blocked by firewall or host routing

## Evidence to capture

- Credential id used
- Cluster name or endpoint
- Output of `kubectl get ns`
- Output of `helm version`
- One successful `helm upgrade --install` log
