# Docker Desktop mount note for k3s master on WSL

Date: 2026-07-04

Context:

- Master node `k3s-master` runs inside Ubuntu WSL.
- Docker Desktop on Windows had injected this mount into the master distro:
  - `/Docker/host`
  - source: `C:\Program Files\Docker\Docker\resources`

Observed issue:

- `k3s` on master started failing repeatedly after restart.
- Symptom in `journalctl -u k3s`:
  - `Failed to start ContainerManager`
  - `system validation failed - wrong number of fields (expected 6, got 7)`
- Likely cause: kubelet on WSL hit a mount parsing problem because the Windows source path contains a space: `Program Files`.

What was done:

- Unmounted the injected Docker Desktop mount inside master WSL:

```bash
sudo umount /Docker/host
```

- Restarted `k3s`, then master recovered successfully.

Result after fix:

- `k3s-master` became `Ready` again.
- Master API on Tailscale IP `100.96.101.91:6443` responded normally.

Important warning:

- This action only removed the mount from the WSL master distro.
- Docker Desktop on Windows was not removed.
- If Docker Desktop restarts, WSL restarts, or integration remounts `/Docker/host`, the same kubelet/k3s failure may return.

Recommended precaution:

- Do not enable Docker Desktop WSL integration for the Ubuntu distro used as `k3s-master`.
- Avoid running Docker Desktop integration against the same WSL distro that hosts the k3s control-plane.

Quick checks:

```bash
mount | grep Docker
ls /Docker
sudo journalctl -u k3s -n 50 --no-pager
```

If the problem returns:

1. Check whether `/Docker/host` is mounted again.
2. Unmount it:

```bash
sudo umount /Docker/host
```

3. Restart k3s:

```bash
sudo systemctl restart k3s
sudo systemctl status k3s --no-pager
```
