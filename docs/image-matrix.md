# Image Matrix

This naming matrix is aligned with the public upstream workflows in `nashtech-garage/yas`, which build images like `yas-storefront`, `yas-product`, and `yas-tax`.

| Service | Docker repository | Default tag | Branch tag rule | Release tag rule |
| --- | --- | --- | --- | --- |
| storefront | `docker.io/<namespace>/yas-storefront` | `main` | latest commit SHA of selected branch | semantic version tag |
| backoffice | `docker.io/<namespace>/yas-backoffice` | `main` | latest commit SHA of selected branch | semantic version tag |
| storefront-bff | `docker.io/<namespace>/yas-storefront-bff` | `main` | latest commit SHA of selected branch | semantic version tag |
| backoffice-bff | `docker.io/<namespace>/yas-backoffice-bff` | `main` | latest commit SHA of selected branch | semantic version tag |
| product | `docker.io/<namespace>/yas-product` | `main` | latest commit SHA of selected branch | semantic version tag |
| media | `docker.io/<namespace>/yas-media` | `main` | latest commit SHA of selected branch | semantic version tag |
| cart | `docker.io/<namespace>/yas-cart` | `main` | latest commit SHA of selected branch | semantic version tag |
| customer | `docker.io/<namespace>/yas-customer` | `main` | latest commit SHA of selected branch | semantic version tag |
| rating | `docker.io/<namespace>/yas-rating` | `main` | latest commit SHA of selected branch | semantic version tag |
| location | `docker.io/<namespace>/yas-location` | `main` | latest commit SHA of selected branch | semantic version tag |
| order | `docker.io/<namespace>/yas-order` | `main` | latest commit SHA of selected branch | semantic version tag |
| inventory | `docker.io/<namespace>/yas-inventory` | `main` | latest commit SHA of selected branch | semantic version tag |
| tax | `docker.io/<namespace>/yas-tax` | `main` | latest commit SHA of selected branch | semantic version tag |
| search | `docker.io/<namespace>/yas-search` | `main` | latest commit SHA of selected branch | semantic version tag |
| promotion | `docker.io/<namespace>/yas-promotion` | `main` | latest commit SHA of selected branch | semantic version tag |
| payment | `docker.io/<namespace>/yas-payment` | `main` | latest commit SHA of selected branch | semantic version tag |
| payment-paypal | `docker.io/<namespace>/yas-payment-paypal` | `main` | latest commit SHA of selected branch | semantic version tag |
| webhook | `docker.io/<namespace>/yas-webhook` | `main` | latest commit SHA of selected branch | semantic version tag |

## Conventions

- Default shared baseline uses `main`.
- Developer builds use commit SHA.
- Staging releases use version tags such as `v1.2.3`.
- The scaffold uses Docker Hub naming, but the upstream repo currently pushes to `ghcr.io/nashtech-garage/`; swap the registry host as needed.
