# Developer Cleanup Runbook

## Goal

Delete the temporary developer deployment created by `developer_build`.

## Inputs

- `DEPLOYER_ID`
- optional `NAMESPACE`
- optional `RELEASE_NAME`
- optional `DELETE_NAMESPACE`, defaulting to `true` for developer environments
- optional `ALLOW_SHARED_ENVIRONMENT_CLEANUP`, required when targeting shared `dev` or `staging`
- optional `ALLOW_SHARED_NAMESPACE_DELETE`, additionally required before deleting the whole shared namespace

## Flow

1. Resolve namespace and release name if not passed explicitly.
2. Run `helm uninstall`.
3. Delete the namespace only when `DELETE_NAMESPACE=true`.
4. Refuse to clean shared `dev` or `staging` environments unless `ALLOW_SHARED_ENVIRONMENT_CLEANUP=true`, even when the caller tries to target them through explicit `NAMESPACE` or `RELEASE_NAME` overrides.
5. Refuse to delete the whole shared namespace unless `ALLOW_SHARED_NAMESPACE_DELETE=true` is also set explicitly.
6. Write cleanup evidence under `work/cleanup-evidence/<namespace>/<release>/`.
7. Print whether the namespace still exists after cleanup.

