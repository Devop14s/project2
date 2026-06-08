# Dev Environment Runbook

## Trigger

Run when `main` changes.

## Behavior

- build images from `main`
- push them with tag `main`
- deploy them into namespace `yas-dev`

## Notes

- Keep dev automatic only after baseline deploys are stable.
- Reuse the same Helm chart and values overlay as developer builds.

