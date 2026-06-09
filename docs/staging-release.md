# Staging Release Runbook

## Trigger

Run for an explicit release version such as `v1.2.3`.

## Behavior

- checkout the release tag or release branch
- build and push release images with the same version tag
- deploy them into namespace `yas-staging`
- run the shared smoke-test helper against the public services and collect runtime evidence
- record the exact promoted source commit in `work/commit_sha.txt`, `work/commit_short_sha.txt`, and `work/commit-metadata.json`

## Notes

- Keep staging immutable per release input.
- Save `work/image-digests.txt` from the push step and reuse those digests in the final report.
- Save `work/runtime-evidence/yas-staging/yas-staging/` after a successful run for screenshots and rollout evidence.
- Save `work/commit-metadata.json` as the source-of-truth link between the release tag and the exact source commit that was built.

