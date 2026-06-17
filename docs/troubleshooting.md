# Troubleshooting

The current generated service snapshot is available at [service-verification.generated.md](</D:/App/project2/work/service-verification.generated.md>) and is refreshed together with [status-report.generated.md](</D:/App/project2/work/status-report.generated.md>) when running `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks`.
The companion host/runtime snapshot is available at [host-capabilities.generated.md](</D:/App/project2/work/host-capabilities.generated.md>) and should be checked first when a failure may come from missing tools, missing `sh`, missing Maven on `PATH`, or Docker daemon reachability rather than from repo logic.

## Common failures

### Docker build path not found

- Check the active catalog file, either `jenkins/services.release-baseline.env` or `jenkins/services.env`.
- Confirm the real YAS repo paths match the configured `path` and `dockerfile`.

### Docker push authentication failure

- Confirm Jenkins credentials are correct.
- Re-run `jenkins/scripts/docker-login.sh` locally inside the Jenkins agent image if needed.
- Confirm the environment that failed actually had the expected Docker CLI and daemon access; compare it against `work/host-capabilities.generated.md` from the machine where local evidence was collected.

### `storefront` Docker build takes too long or times out

- Re-run the build on a host with a longer timeout and warm package cache.
- Confirm the `.next` build output already exists before running `docker build`.
- Treat a timeout as an infrastructure/runtime issue, not immediate proof that the Dockerfile is wrong.

### Helm upgrade fails

- Run `helm template` first.
- Confirm `work/generated-values.yaml` exists and contains valid YAML.
- If Helm is reported missing globally, check whether the portable binary under `work/tools/` should have been used instead, as captured in `work/host-capabilities.generated.md`.

### Pods do not become ready

- Inspect `kubectl get pods -n <namespace>`.
- Check container environment variables, service dependencies, and image tags.

### NodePort is open but app is unreachable

- Verify container port mapping.
- Verify application bind address and service target port.
- Confirm worker-node firewall rules.

### `recommendation` Maven build fails only during parallel local verification

- Avoid running multiple `mvn clean install -pl <service> -am` reactors at the same time in the same source workspace, especially the clean `yas-source-upstream` clone used for evidence generation.
- The earlier failure observed here came from concurrent cleanup of `common-library/target`, not from a service-code failure.

### `sampledata` full upstream-style build fails in this workspace

- Capture the exact `common-library` test compilation failure first.
- If the assignment does not require `sampledata` in the first release, keep it out of the deployable subset and document that decision explicitly.
- If it is required, isolate whether the failure is caused by Java version, dependency state, or local workspace contamination.

### `cart`, `customer`, `location`, `media`, `promotion`, `rating`, `tax`, or `webhook` integration tests fail while waiting for Keycloak

- The concrete failure seen on this host is Keycloak Testcontainers startup timing out on `/health/started`.
- Check Docker Desktop resource limits, container startup logs, and whether the Keycloak image is already cached.
- If the host that is rerunning the tests differs from the original local verification host, capture a fresh `work/host-capabilities.generated.md` first so Docker/CLI/runtime differences are explicit.
- If the immediate goal is delivery-repo coverage rather than integration-test repair, keep the package-and-image evidence and document the full-test blocker explicitly.

### `search` full upstream-style build fails in `ProductCdcConsumerTest`

- Check whether Elasticsearch Testcontainers can pull and start the expected image on the host.
- Inspect container startup logs and readiness timeout settings.
- If `search` is not mandatory for the first release, exclude it temporarily and record the justification.

### `backoffice` build logs print `quill` SSR traces

- If `npm run build` still exits `0` and `.next` is produced, treat this as a warning-level observation rather than a build blocker.
- Revisit only if runtime behavior or build exit codes become unstable.

