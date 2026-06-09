# Staging Release Runbook

## Trigger

Run for an explicit release version such as `v1.2.3`.

## Behavior

- checkout the release tag or release branch
- build and push release images with the same version tag
- deploy them into namespace `yas-staging`
- run the shared smoke-test helper against the public services and collect runtime evidence

## Notes

- Keep staging immutable per release input.
- Record image digests in the final report if possible.
- Save `work/runtime-evidence/yas-staging/yas-staging/` after a successful run for screenshots and rollout evidence.

