# Yêu cầu 1: Chiến lược Image mặc định

## Tóm tắt yêu cầu

- Mỗi service chỉ có **1 image** trên Docker Hub.
- Tag mặc định là `main` hoặc `latest` (dùng nhất quán, khuyến nghị `main`).
- **Không triển khai** Grafana, Prometheus, OpenTelemetry (bỏ qua Observability stack).

---

## Danh sách service cần build image

Dựa trên kiến trúc YAS, các service cần build image và push lên Docker Hub:

| Service | Repo path trong YAS | Image name (gợi ý) | Ghi chú |
|---|---|---|---|
| product | `product/` | `<namespace>/yas-product` | Trung tâm shop |
| cart | `cart/` | `<namespace>/yas-cart` | Demo flow mua hàng |
| order | `order/` | `<namespace>/yas-order` | Demo retry policy |
| customer | `customer/` | `<namespace>/yas-customer` | Thông tin khách |
| inventory | `inventory/` | `<namespace>/yas-inventory` | Order phụ thuộc |
| tax | `tax/` | `<namespace>/yas-tax` | Demo VirtualService retry |
| media | `media/` | `<namespace>/yas-media` | Upload hình sản phẩm |
| search | `search/` | `<namespace>/yas-search` | Demo AuthorizationPolicy |
| storefront-bff | `storefront-bff/` | `<namespace>/yas-storefront-bff` | BFF giao diện người dùng |
| storefront-ui | `storefront/` | `<namespace>/yas-storefront` | UI cửa hàng — demo GV |
| backoffice-bff | `backoffice-bff/` | `<namespace>/yas-backoffice-bff` | BFF quản trị |
| backoffice-ui | `backoffice/` | `<namespace>/yas-backoffice` | UI quản trị |
| swagger-ui | `swagger-ui/` | `<namespace>/yas-swagger` | API documentation |
| sampledata | `sampledata/` | `<namespace>/yas-sampledata` | Chỉ chạy 1 lần để seed data |

> Tổng: **14 services** — sampledata chỉ chạy 1 lần (Job hoặc K8S Job), sau đó có thể scale về 0.

> **`<namespace>`** = tên Docker Hub username hoặc organization của nhóm.  
> Infra services (PostgreSQL, Kafka, Elasticsearch) dùng **official public image**, không cần build.

---

## Service KHÔNG build (dùng official image)

| Service | Official image |
|---|---|
| PostgreSQL | `postgres:15` |
| Apache Kafka | `confluentinc/cp-kafka:7.x` hoặc `bitnami/kafka` |
| Kafka Connect + Debezium | `debezium/connect:2.x` |
| Elasticsearch | `elasticsearch:8.x` |
| Nginx | `nginx:alpine` |
| pgAdmin | `dpage/pgadmin4` |

---

## Service bỏ qua (không triển khai trong đồ án)

- Grafana
- Prometheus
- Grafana Loki
- Grafana Tempo
- OpenTelemetry Collector

---

## Cấu hình Docker Hub

### Bước 1: Tạo repository trên Docker Hub

1. Đăng nhập vào [hub.docker.com](https://hub.docker.com).
2. Tạo các repository tương ứng với từng service **hoặc** dùng một namespace chung, tag theo tên service.
3. Gợi ý đặt tên: `<dockerhub-username>/yas-<service-name>`.

### Bước 2: Tạo Access Token

1. Docker Hub → Account Settings → Security → **New Access Token**.
2. Đặt tên token (ví dụ: `jenkins-ci`), quyền `Read & Write`.
3. Lưu token vào Jenkins Credentials:
   - Kind: **Username with password**
   - ID: `dockerhub-credentials`
   - Username: Docker Hub username
   - Password: Access Token vừa tạo

### Bước 3: Xác nhận push thủ công (test một lần)

```bash
docker login -u <username> -p <access-token>

# Build thử 1 service
docker build -t <username>/yas-tax:main ./tax

# Push
docker push <username>/yas-tax:main

# Kiểm tra trên Docker Hub
docker pull <username>/yas-tax:main && echo "OK"
```

---

## Tag convention

| Trường hợp | Tag |
|---|---|
| Branch `main` merge hoặc build thường | `main` |
| Tương đương `main` | `latest` (alias) |
| Build từ branch developer (CI requirement 3) | `<commit-sha-7-ký-tự>` |
| Release staging (optional nâng cao) | `v1.2.3` |

> Trong đồ án này, tag `main` = tag chuẩn cho tất cả môi trường ổn định.

---

## Helm values mặc định

Trong file `values.yaml` của Helm chart, set default tag:

```yaml
global:
  imageRegistry: docker.io/<namespace>
  imageTag: main

services:
  tax:
    image: yas-tax
    tag: ""   # rỗng = dùng global.imageTag

  product:
    image: yas-product
    tag: ""

  # ... tương tự các service khác
```

---

## Checklist xác nhận

- [ ] Docker Hub namespace đã tạo
- [ ] Jenkins credential `dockerhub-credentials` đã cấu hình
- [ ] Đã test `docker login` từ Jenkins agent thành công
- [ ] Image `main` của ít nhất 1 service đã push lên Docker Hub
- [ ] Helm values mặc định dùng tag `main`
- [ ] Xác nhận KHÔNG có resource nào deploy Grafana / Prometheus trong Helm chart
