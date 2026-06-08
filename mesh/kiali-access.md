# Kiali Access Notes

## Example commands

```bash
kubectl -n istio-system port-forward svc/kiali 20001:20001
```

Open `http://localhost:20001` and navigate to the target namespace after generating traffic.

