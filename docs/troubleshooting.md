# Troubleshooting

## Common failures

### Docker build path not found

- Check `jenkins/services.env`.
- Confirm the real YAS repo paths match the configured `path` and `dockerfile`.

### Docker push authentication failure

- Confirm Jenkins credentials are correct.
- Re-run `jenkins/scripts/docker-login.sh` locally inside the Jenkins agent image if needed.

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

