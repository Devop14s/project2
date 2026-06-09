# Deployment Topology

## Namespaces

- `yas-dev`
- `yas-staging`
- `yas-user-<developer-id>`

## Release names

- `yas-dev`
- `yas-staging`
- `yas-<developer-id>`

## Access pattern

- Internal services use `ClusterIP`.
- User-facing entrypoints use `NodePort`.
- Developers map hostnames manually in the local `hosts` file to the worker-node IP.
- Shared deploy helpers now default public UI hosts by environment: `*-<developer-id>.yas.local` for developer runs, `*-dev.yas.local` for `dev`, and `*-staging.yas.local` for `staging`.

## Example host mapping

| Environment | Hostname | NodePort |
| --- | --- | --- |
| developer | `storefront-<developer-id>.yas.local` | `32080` |
| dev | `storefront-dev.yas.local` | `32080` |
| staging | `storefront-staging.yas.local` | `32080` |

