# Developer Cleanup Runbook

## Goal

Delete the temporary developer deployment created by `developer_build`.

## Inputs

- `DEPLOYER_ID`
- optional `NAMESPACE`
- optional `RELEASE_NAME`

## Flow

1. Resolve namespace and release name if not passed explicitly.
2. Run `helm uninstall`.
3. Optionally delete the namespace.
4. Print remaining resources if any are still present.

