# Requirement Final Evidence

Date: 2026-07-07

This file is the short handover summary for the final state of the project.

## Cluster

- `k3s-master` is `Ready` on Tailscale IP `100.96.101.91`.
- `k3s-worker` is `Ready` on Tailscale IP `100.82.170.68`.
- The legacy `desktop-brprq5f` node still exists as `NotReady` and should be treated as stale.

## Runtime

- UI workloads are pinned to the master.
- Backend workloads run on the worker.
- `keycloak` is deployed and responding.
- `product` can reach `media` correctly after the direct-service routing fix.

## Key Evidence

- Kiali topology screenshot:
  - `work/evidence/kiali-yas-dev-topology.png`
- Kiali graph JSON:
  - `work/evidence/kiali-yas-dev-graph.json`
- Retry proof:
  - `work/evidence-retry.txt`
- Authorization deny proof:
  - `work/evidence-mtls-deny.txt`
- Mesh snapshot:
  - `work/evidence-mesh-config.txt`
- CI evidence for commit-tagged image push:
  - `work/evidence/ci-image-evidence-build-5.txt`
- Jenkins multibranch trigger config evidence:
  - `work/evidence/jenkins-multibranch-trigger-config.xml`

## CI / GitOps

- CI branch build pushed `luongtrz/yas-media:ab212ec`.
- Build was triggered automatically by Jenkins multibranch indexing, not by a manual build trigger.
- Dev and staging ArgoCD environments were reported as Synced and Healthy in the latest runtime state.

## Notes

- The delivery repo keeps the evidence files in `work/evidence/`.
- The project handover should cite the files above instead of referring to terminal output directly.
