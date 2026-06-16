# Image Matrix

This matrix keeps the intended naming convention and also records the current local verification status of each image path.

The machine-generated per-service snapshot is available at [service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>) and is refreshed together with [status-report.generated.md](</D:/App/project2/work/status-report.generated.md>) when running `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks`.
Use [host-capabilities.generated.md](</D:/App/project2/work/host-capabilities.generated.md>) alongside this matrix when a local image verification status may be limited by Docker daemon access or missing host tools rather than by repo logic.

| Service | Docker repository | Default tag | Branch tag rule | Release tag rule | Local image verification |
| --- | --- | --- | --- | --- | --- |
| storefront | `docker.io/<namespace>/yas-storefront` | `main` | latest commit SHA of selected branch | semantic version tag | local `docker build` now passes and produces `yas-storefront:codex-verified` |
| backoffice | `docker.io/<namespace>/yas-backoffice` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| storefront-bff | `docker.io/<namespace>/yas-storefront-bff` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| backoffice-bff | `docker.io/<namespace>/yas-backoffice-bff` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| product | `docker.io/<namespace>/yas-product` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| media | `docker.io/<namespace>/yas-media` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| cart | `docker.io/<namespace>/yas-cart` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| customer | `docker.io/<namespace>/yas-customer` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| rating | `docker.io/<namespace>/yas-rating` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| location | `docker.io/<namespace>/yas-location` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| order | `docker.io/<namespace>/yas-order` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| inventory | `docker.io/<namespace>/yas-inventory` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| tax | `docker.io/<namespace>/yas-tax` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| search | `docker.io/<namespace>/yas-search` | `main` | latest commit SHA of selected branch | semantic version tag | verified, but full test path still blocked |
| promotion | `docker.io/<namespace>/yas-promotion` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| payment | `docker.io/<namespace>/yas-payment` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| payment-paypal | `docker.io/<namespace>/yas-payment-paypal` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| recommendation | `docker.io/<namespace>/yas-recommendation` | `main` | latest commit SHA of selected branch | semantic version tag | verified |
| sampledata | `docker.io/<namespace>/yas-sampledata` | `main` | latest commit SHA of selected branch | semantic version tag | verified, but full test path still blocked |
| webhook | `docker.io/<namespace>/yas-webhook` | `main` | latest commit SHA of selected branch | semantic version tag | verified |

## Conventions

- Default shared baseline uses `main`.
- Developer builds use commit SHA.
- Staging releases use version tags such as `v1.2.3`.
- The scaffold uses Docker Hub naming, but the upstream repo currently pushes to `ghcr.io/nashtech-garage/`; swap the registry host as needed.
- A `verified` status here means a local `docker build` completed successfully in this workspace. It does not yet mean the image was pushed to a real registry.
- If `docker` is installed but the daemon is unreachable in the current execution context, `work/host-capabilities.generated.md` is the authoritative local explanation for missing or incomplete image-verification lines.
