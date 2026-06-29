# Kế hoạch triển khai Service Mesh (Nâng cao — 2đ)

## Tổng quan

Mục tiêu: cài Istio lên K3s, bật mTLS cho namespace `yas-dev`, định nghĩa
AuthorizationPolicy theo đúng flow service, cấu hình retry policy cho `order`/`tax`,
rồi chụp evidence bằng Kiali và `curl` test.

---

## Trạng thái hiện tại

| File | Trạng thái | Ghi chú |
|---|---|---|
| `mesh/peer-authentication.yaml` | Có | STRICT mTLS cho `yas-dev` |
| `mesh/destination-rule.yaml` | Có | ISTIO_MUTUAL cho tất cả services |
| `mesh/authorization-policy.yaml` | **Thiếu** | Chỉ có 1 rule product←storefront-bff, cần mở rộng toàn bộ |
| `mesh/virtual-service-retry.yaml` | **Bug** | Port `8080` sai — backend dùng port `80` |
| Istio trên cluster | **Chưa cài** | |
| Kiali | **Chưa cài** | |

---

## Bước 1 — Cài Istio lên K3s

K3s dùng Flannel CNI, không cần thay đổi CNI để chạy Istio. Dùng `istioctl` để cài.

### 1a. Tải istioctl

```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.22.0 sh -
export PATH="$PWD/istio-1.22.0/bin:$PATH"
istioctl version
```

### 1b. Cài Istio với profile `demo`

Profile `demo` bật thêm tracing và metrics — phù hợp cho báo cáo.

```bash
istioctl install --set profile=demo -y
kubectl get pods -n istio-system
```

Chờ tất cả pods Ready:

```bash
kubectl -n istio-system rollout status deploy/istiod
kubectl -n istio-system rollout status deploy/istio-ingressgateway
```

### 1c. Enable sidecar injection cho namespace `yas-dev`

```bash
kubectl label namespace yas-dev istio-injection=enabled
kubectl get namespace yas-dev --show-labels
```

**Quan trọng:** phải restart pods sau khi label namespace để Istio inject sidecar:

```bash
kubectl rollout restart deployment -n yas-dev
kubectl get pods -n yas-dev
# Kỳ vọng: mỗi pod có 2/2 READY (container + envoy sidecar)
```

---

## Bước 2 — Cài Kiali

Kiali cần Prometheus để hiển thị metrics. Cài cả hai từ Istio addons:

```bash
kubectl apply -f istio-1.22.0/samples/addons/prometheus.yaml
kubectl apply -f istio-1.22.0/samples/addons/kiali.yaml
kubectl -n istio-system rollout status deploy/kiali
```

Expose Kiali qua NodePort:

```bash
kubectl patch svc kiali -n istio-system \
  -p '{"spec":{"type":"NodePort","ports":[{"port":20001,"targetPort":20001,"nodePort":30001}]}}'
```

Truy cập: `http://192.168.11.26:30001` (user: `admin`, pass: `admin`)

---

## Bước 3 — Apply mTLS (đã có file, chỉ cần apply)

```bash
kubectl apply -f mesh/peer-authentication.yaml
kubectl apply -f mesh/destination-rule.yaml
```

Xác nhận mTLS active:

```bash
istioctl x describe service product.yas-dev
# Output nên có: "Port Product 80 (HTTP) → Enforcing mTLS"
```

---

## Bước 4 — Fix VirtualService và mở rộng retry policy

### Bug cần sửa: port sai

File hiện tại `mesh/virtual-service-retry.yaml` dùng port `8080`, nhưng backend
services dùng containerPort `80`. Cần sửa.

### Chiến lược retry

Theo requirement, demo retry cho:
- **`order`** — phụ thuộc `cart`, `inventory`, `tax`; dễ xảy ra lỗi transient
- **`tax`** — được đề cập cụ thể trong đề bài

Nội dung sửa `mesh/virtual-service-retry.yaml`:

```yaml
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: order-retry
  namespace: yas-dev
spec:
  hosts:
    - order.yas-dev.svc.cluster.local
  http:
    - retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,connect-failure,refused-stream
      route:
        - destination:
            host: order.yas-dev.svc.cluster.local
            port:
              number: 80
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tax-retry
  namespace: yas-dev
spec:
  hosts:
    - tax.yas-dev.svc.cluster.local
  http:
    - retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,connect-failure,refused-stream
      route:
        - destination:
            host: tax.yas-dev.svc.cluster.local
            port:
              number: 80
```

Apply:

```bash
kubectl apply -f mesh/virtual-service-retry.yaml
```

---

## Bước 5 — Mở rộng AuthorizationPolicy

### Kiến trúc giao tiếp YAS (14 services)

```
storefront (UI)  ──→  storefront-bff  ──→  product
                                       ──→  cart
                                       ──→  order
                                       ──→  customer
                                       ──→  tax
                                       ──→  media
                                       ──→  search

backoffice (UI)  ──→  backoffice-bff  ──→  product
                                       ──→  order
                                       ──→  customer
                                       ──→  inventory
                                       ──→  tax
                                       ──→  media
                                       ──→  search

order  ──→  cart
order  ──→  inventory
order  ──→  tax

search  ──→  product (index)

sampledata  ──→  product, cart, order, customer, inventory, tax (seed)
```

### Chiến lược: default-deny + explicit allow

Cần 1 deny-all rule trong namespace, rồi explicit allow cho từng service.

Nội dung đầy đủ cho `mesh/authorization-policy.yaml`:

```yaml
# Default deny-all cho namespace yas-dev
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: yas-dev
spec: {}

# product: storefront-bff, backoffice-bff, search, sampledata
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: product-allow
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: product
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas-dev/sa/storefront-bff
              - cluster.local/ns/yas-dev/sa/backoffice-bff
              - cluster.local/ns/yas-dev/sa/search
              - cluster.local/ns/yas-dev/sa/sampledata

# cart: storefront-bff, order, sampledata
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: cart-allow
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: cart
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas-dev/sa/storefront-bff
              - cluster.local/ns/yas-dev/sa/order
              - cluster.local/ns/yas-dev/sa/sampledata

# order: storefront-bff, backoffice-bff, sampledata
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: order-allow
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: order
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas-dev/sa/storefront-bff
              - cluster.local/ns/yas-dev/sa/backoffice-bff
              - cluster.local/ns/yas-dev/sa/sampledata

# customer: storefront-bff, backoffice-bff, sampledata
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: customer-allow
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: customer
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas-dev/sa/storefront-bff
              - cluster.local/ns/yas-dev/sa/backoffice-bff
              - cluster.local/ns/yas-dev/sa/sampledata

# inventory: backoffice-bff, order, sampledata
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: inventory-allow
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: inventory
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas-dev/sa/backoffice-bff
              - cluster.local/ns/yas-dev/sa/order
              - cluster.local/ns/yas-dev/sa/sampledata

# tax: storefront-bff, backoffice-bff, order, sampledata
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: tax-allow
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: tax
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas-dev/sa/storefront-bff
              - cluster.local/ns/yas-dev/sa/backoffice-bff
              - cluster.local/ns/yas-dev/sa/order
              - cluster.local/ns/yas-dev/sa/sampledata

# media: storefront-bff, backoffice-bff, sampledata
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: media-allow
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: media
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas-dev/sa/storefront-bff
              - cluster.local/ns/yas-dev/sa/backoffice-bff
              - cluster.local/ns/yas-dev/sa/sampledata

# search: storefront-bff, sampledata
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: search-allow
  namespace: yas-dev
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: search
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/yas-dev/sa/storefront-bff
              - cluster.local/ns/yas-dev/sa/sampledata
```

**Lưu ý về ServiceAccount:** Istio dùng SPIFFE identity theo format
`cluster.local/ns/<namespace>/sa/<serviceaccount-name>`. Helm chart cần tạo
ServiceAccount cho mỗi service với tên khớp với service name. Kiểm tra:

```bash
kubectl get serviceaccounts -n yas-dev
```

Nếu pods dùng `default` SA, phải sửa Helm chart hoặc tạo SA riêng cho từng service.

---

## Bước 6 — Apply tất cả manifest

```bash
kubectl apply -f mesh/peer-authentication.yaml
kubectl apply -f mesh/destination-rule.yaml
kubectl apply -f mesh/virtual-service-retry.yaml
kubectl apply -f mesh/authorization-policy.yaml
```

Kiểm tra:

```bash
kubectl get peerauthentication -n yas-dev
kubectl get destinationrule -n yas-dev
kubectl get authorizationpolicy -n yas-dev
kubectl get virtualservice -n yas-dev
```

---

## Bước 7 — Test kịch bản

### Test 7a: mTLS hoạt động (ALLOW)

```bash
# Từ pod storefront-bff, curl tới product — phải PASS
kubectl exec -n yas-dev deploy/storefront-bff \
  -- curl -s http://product.yas-dev:80/api/v1/products | head -c 200
```

### Test 7b: AuthorizationPolicy BLOCK

```bash
# Tạo pod test không có trong whitelist
kubectl run test-denied --image=curlimages/curl -n yas-dev \
  --restart=Never --rm -it -- \
  curl -v http://product.yas-dev:80/api/v1/products
# Kỳ vọng: 403 Forbidden — RBAC: access denied
```

### Test 7c: Retry policy

Cần tạm thời inject lỗi vào `tax` service để xem retry:

```bash
# Inject fault vào tax (50% lỗi 500) bằng VirtualService fault injection
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tax-fault-inject
  namespace: yas-dev
spec:
  hosts:
    - tax.yas-dev.svc.cluster.local
  http:
    - fault:
        abort:
          httpStatus: 500
          percentage:
            value: 50
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx
      route:
        - destination:
            host: tax.yas-dev.svc.cluster.local
            port:
              number: 80
EOF
```

Gọi tax nhiều lần, quan sát trong Kiali rằng có retry traffic:

```bash
kubectl exec -n yas-dev deploy/order -- \
  for i in $(seq 1 10); do curl -s http://tax.yas-dev:80/api/v1/taxes; done
```

Xóa fault sau khi test:

```bash
kubectl delete virtualservice tax-fault-inject -n yas-dev
```

---

## Bước 8 — Thu evidence

### 8a. Kiali Topology

1. Mở `http://192.168.11.26:30001`
2. Graph → Namespace: `yas-dev`
3. Chụp screenshot toàn bộ topology
4. Bật "Security" badge để hiển thị mTLS lock icon

### 8b. Logs retry từ Envoy

```bash
# Xem access log của envoy sidecar trong order pod
kubectl logs -n yas-dev deploy/order -c istio-proxy | grep -i "retry\|x-envoy-attempt-count"
```

### 8c. Evidence cho báo cáo

```bash
# mTLS status
istioctl x describe service product.yas-dev
istioctl x describe service tax.yas-dev

# AuthorizationPolicy list
kubectl get authorizationpolicy -n yas-dev -o yaml

# Istio proxy config
istioctl proxy-config listener deploy/order.yas-dev --port 80

# Kết quả curl test (lưu vào file)
kubectl exec -n yas-dev deploy/storefront-bff -- \
  curl -sv http://product.yas-dev:80/api/v1/products 2>&1 | head -30 \
  > work/evidence-mtls-allow.txt

kubectl run test-denied --image=curlimages/curl -n yas-dev \
  --restart=Never --rm -- \
  curl -sv http://product.yas-dev:80/api/v1/products 2>&1 \
  > work/evidence-mtls-deny.txt
```

---

## Bước 9 — Update mesh files (nếu chỉnh sửa kịch bản)

Sau khi test xong, update lại `mesh/authorization-policy.yaml` và
`mesh/virtual-service-retry.yaml` với nội dung đầy đủ rồi commit:

```bash
git add mesh/
git commit -m "feat(mesh): full authorization policies and retry for 14 services"
git push origin main
```

---

## Checklist hoàn thành

- [ ] Istio cài xong, pods trong `istio-system` đều Ready
- [ ] Kiali truy cập được tại `http://192.168.11.26:30001`
- [ ] Namespace `yas-dev` có label `istio-injection=enabled`
- [ ] Pods restart, mỗi pod có 2/2 READY (sidecar injected)
- [ ] `mesh/peer-authentication.yaml` apply → mTLS STRICT
- [ ] `mesh/destination-rule.yaml` apply → ISTIO_MUTUAL
- [ ] `mesh/authorization-policy.yaml` apply → deny-all + explicit allows
- [ ] `mesh/virtual-service-retry.yaml` apply → retry 3 lần cho order+tax
- [ ] Test ALLOW: `storefront-bff → product` pass
- [ ] Test DENY: pod không có whitelist → 403
- [ ] Test retry: fault injection vào `tax`, log có `x-envoy-attempt-count: 2` hoặc `3`
- [ ] Screenshot Kiali topology với mTLS lock icon
- [ ] Evidence files lưu trong `work/`

---

## Ghi chú kỹ thuật

### K3s + Istio: vấn đề cần biết

1. K3s dùng **Flannel** CNI — không conflict với Istio sidecar injection.
2. K3s có **built-in Traefik** ingress. Nếu Istio IngressGateway conflict port,
   disable Traefik: thêm `--disable traefik` vào k3s server args.
3. K3s có thể dùng `containerd` thay Docker — không ảnh hưởng Istio.

### ServiceAccount cho SPIFFE identity

AuthorizationPolicy dùng `principals` dựa trên ServiceAccount name. Nếu Helm chart
không tạo SA riêng, tất cả pods dùng `default` SA và policy sẽ không phân biệt được
từng service.

Fix nhanh: tạo SA riêng bằng kubectl trước khi test:

```bash
for svc in storefront-bff backoffice-bff product cart order customer inventory tax media search sampledata; do
  kubectl create serviceaccount $svc -n yas-dev --dry-run=client -o yaml | kubectl apply -f -
done
```

Rồi patch deployment để dùng đúng SA:

```bash
kubectl patch deploy storefront-bff -n yas-dev \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"storefront-bff"}}}}'
# Lặp tương tự cho các service còn lại
```

Hoặc sửa trong `helm/yas/values-dev.yaml` thêm `serviceAccountName` cho mỗi service.

### Virtual Service port

Backend services (product, cart, order, v.v.) dùng containerPort `80`.
`storefront` và `backoffice` dùng containerPort `3000`.
`swagger-ui` dùng containerPort `8080`.
Luôn dùng đúng port trong VirtualService.
