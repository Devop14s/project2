# Troubleshooting

## Common failures

### Docker build path not found

- Check the active catalog file, either `jenkins/services.release-baseline.env` or `jenkins/services.env`.
- Confirm the real YAS repo paths match the configured `path` and `dockerfile`.

### Docker push authentication failure

- Confirm Jenkins credentials are correct.
- Re-run `jenkins/scripts/docker-login.sh` locally inside the Jenkins agent image if needed.

### `storefront` Docker build takes too long or times out

- Re-run the build on a host with a longer timeout and warm package cache.
- Confirm the `.next` build output already exists before running `docker build`.
- Treat a timeout as an infrastructure/runtime issue, not immediate proof that the Dockerfile is wrong.

### Helm upgrade fails

- Run `helm template` first.
- Confirm `work/generated-values.yaml` exists and contains valid YAML.

### Pods do not become ready

- Inspect `kubectl get pods -n <namespace>`.
- Check container environment variables, service dependencies, and image tags.

### NodePort is open but app is unreachable

- Verify container port mapping.
- Verify application bind address and service target port.
- Confirm worker-node firewall rules.

### `recommendation` Maven build fails only during parallel local verification

- Avoid running multiple `mvn clean install -pl <service> -am` reactors at the same time in the same `yas-source` workspace.
- The earlier failure observed here came from concurrent cleanup of `common-library/target`, not from a service-code failure.

### `sampledata` full upstream-style build fails in this workspace

- Capture the exact `common-library` test compilation failure first.
- If the assignment does not require `sampledata` in the first release, keep it out of the deployable subset and document that decision explicitly.
- If it is required, isolate whether the failure is caused by Java version, dependency state, or local workspace contamination.

### `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, or `webhook` integration tests fail while waiting for Keycloak

- The concrete failure seen on this host is Keycloak Testcontainers startup timing out on `/health/started`.
- Check Docker Desktop resource limits, container startup logs, and whether the Keycloak image is already cached.
- If the immediate goal is delivery-repo coverage rather than integration-test repair, keep the package-and-image evidence and document the full-test blocker explicitly.

### `search` full upstream-style build fails in `ProductCdcConsumerTest`

- Check whether Elasticsearch Testcontainers can pull and start the expected image on the host.
- Inspect container startup logs and readiness timeout settings.
- If `search` is not mandatory for the first release, exclude it temporarily and record the justification.

### `backoffice` build logs print `quill` SSR traces

- If `npm run build` still exits `0` and `.next` is produced, treat this as a warning-level observation rather than a build blocker.
- Revisit only if runtime behavior or build exit codes become unstable.

