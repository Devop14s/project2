# Dev Environment Runbook

## Trigger

Run when `main` changes.

## Behavior

- build images from `main`
- push them with tag `main`
- deploy them into namespace `yas-dev`
- record the exact promoted source commit in `work/commit_sha.txt`, `work/commit_short_sha.txt`, and `work/commit-metadata.json`

## Notes

- Keep dev automatic only after baseline deploys are stable.
- Reuse the same Helm chart and values overlay as developer builds.
- `dev` intentionally keeps the mutable `main` tag as the shared baseline; use the commit-metadata artifacts to identify the exact source revision that was promoted in a given run.
- `work/commit-metadata.json` now embeds both `commit_sha` and `commit_short_sha`, so the JSON file itself is enough for report excerpts.

