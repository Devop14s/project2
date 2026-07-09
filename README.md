# YAS — CI/CD, GitOps & Service Mesh

Đồ án môn DevOps: xây dựng hệ thống CI/CD hoàn chỉnh để build, triển khai và vận hành ứng dụng microservice **YAS (Yet Another Shop)** trên Kubernetes, dùng Jenkins, ArgoCD (GitOps) và Istio Service Mesh.

Báo cáo nộp (kèm ảnh minh chứng) nằm trong [`report/`](report/) — xem [`report/22120061_22120062_22120199_22120363.docx`](report/22120061_22120062_22120199_22120363.docx) (bản nộp chính thức) hoặc [`report/BAO-CAO-CHI-TIET.md`](report/BAO-CAO-CHI-TIET.md) (bản chi tiết, có mục lục).

## Kiến trúc hạ tầng

- Kubernetes cluster: k3s, 1 master (`k3s-master`) + 1 worker (`k3s-worker`), nối qua Tailscale.
- 3 môi trường:
  - **Developer sandbox** (`yas-user-<deployer-id>`): tạo/xóa theo yêu cầu qua Jenkins `developer_build` / `developer_cleanup`.
  - **Dev** (`yas-dev`): Jenkins cập nhật manifest, ArgoCD tự đồng bộ (`prune` + `selfHeal`).
  - **Staging** (`yas-staging`): Jenkins cập nhật manifest, ArgoCD đồng bộ thủ công.
- 14 service bắt buộc (product, cart, order, customer, inventory, tax, media, search, storefront(-bff), backoffice(-bff), swagger-ui, sampledata) + hạ tầng phụ trợ (Keycloak, PostgreSQL, Kafka/Kafka Connect, Elasticsearch, Redis).

## CI/CD Pipeline (Jenkins)

| Pipeline | Vai trò |
|---|---|
| `ci` | Build + push image Docker Hub theo tag `main`/`latest` hoặc commit id của từng nhánh |
| `developer_build` | Triển khai môi trường riêng cho developer, nhận tham số nhánh nguồn theo từng service, trả về NodePort để test |
| `developer_cleanup` | Xóa môi trường developer đã tạo, có cơ chế chặn xóa nhầm `yas-dev`/`yas-staging` |
| `dev_gitops` / `staging_gitops` | Cập nhật file values GitOps rồi push, để ArgoCD đồng bộ xuống `yas-dev`/`yas-staging` |

Chi tiết từng stage, script, tham số: xem `jenkins/pipelines/`, `jenkins/scripts/`, và mục 6–10 trong `report/BAO-CAO-CHI-TIET.md`.

## GitOps (ArgoCD)

- `argocd/app-dev.yaml`, `argocd/app-staging.yaml`: định nghĩa Application cho từng môi trường.
- `argocd/values/`: file values riêng theo môi trường, được Jenkins cập nhật tự động sau mỗi lần release.

## Service Mesh (Istio + Kiali)

- `mesh/`: `PeerAuthentication` (mTLS STRICT), `DestinationRule`, `AuthorizationPolicy` (allow/deny theo ServiceAccount), `VirtualService` (retry policy).
- `infra/`: ngoại lệ mTLS cho hạ tầng không có sidecar (PostgreSQL, Kafka, Elasticsearch) và cho UI (Next.js) không hỗ trợ mTLS ngược.
- Xem `mesh/README.md` để biết thứ tự apply, và `docs/service-mesh-test-plan.md` / `docs/service-mesh-results.md` cho test plan + kết quả thật.

## Helm chart

- `helm/yas/`: chart dùng chung cho cả 3 tầng triển khai (developer sandbox, dev, staging), khác nhau qua file values (`values-dev-dual-worker.yaml`, `values-staging.yaml`, hoặc values sinh tự động bởi `developer_build`).

## Chạy kiểm tra nhanh

```bash
bash run-dev.sh       # port-forward + curl-check toàn bộ endpoint yas-dev
bash run-staging.sh   # port-forward + curl-check toàn bộ endpoint yas-staging
```

## Cấu trúc repo

```text
argocd/       Application manifest + values cho ArgoCD (dev, staging)
docker/       Dockerfile phụ trợ
docs/         Test plan & kết quả thật cho Service Mesh
helm/yas/     Helm chart dùng chung cho 3 môi trường
infra/        Ngoại lệ DestinationRule cho hạ tầng/UI không dùng mTLS
jenkins/      Pipeline Jenkins (ci, developer_build, developer_cleanup, gitops) + script shell
mesh/         Manifest Istio: PeerAuthentication, AuthorizationPolicy, VirtualService retry
report/       Báo cáo nộp (.docx), báo cáo chi tiết (.md), ảnh + log minh chứng
scripts/      Script hỗ trợ sinh values, kiểm tra local
setup/        Script dựng cụm k3s (systemd, master, worker, kubeconfig, namespace)
work/         Evidence runtime, script bootstrap Jenkins, artifact build
yas-source/   Mã nguồn các service YAS (fork/checkout)
```

## Yêu cầu đề bài

Xem [`Project02_HKII_25_26.md`](Project02_HKII_25_26.md) (đề bài) và [`Requirement-service.md`](Requirement-service.md) (danh mục service bắt buộc). Đối chiếu yêu cầu ↔ minh chứng chi tiết nằm ở mục 13–14 trong `report/BAO-CAO-CHI-TIET.md`.
