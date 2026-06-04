# Phase 0-1: Discovery Và Foundation

## Phase 0 - Khảo sát và chốt thiết kế

### Mục tiêu

Biến repo YAS thật thành danh sách thành phần cần build/deploy, đồng thời chốt kiến trúc CI/CD/K8S trước khi viết pipeline.

### Đầu vào

- Repo `nashtech-garage/yas`
- Đề bài
- Tài khoản Docker Hub
- Máy/VM để dựng K8S và Jenkins

### Đầu ra

- Bảng kiểm kê service
- Bảng map service -> Docker image -> port -> dependency
- Quyết định cluster type, Helm structure, namespace strategy, branch strategy

### Checklist công việc

1. Clone repo YAS và đọc `README`, `docker-compose`, các thư mục service.
2. Liệt kê toàn bộ service runtime:
   - business services
   - BFF
   - frontend
   - identity
   - tooling thật sự cần deploy
3. Đánh dấu service nào:
   - bắt buộc phải chạy để demo
   - có thể giữ mặc định bằng image `main`
   - có dependency nặng như Kafka/Elasticsearch/Postgres
4. Kiểm tra mỗi service hiện build bằng gì:
   - Maven/Gradle
   - Dockerfile có sẵn hay chưa
   - multi-stage build hay chưa
5. Kiểm tra frontend/BFF:
   - có cần env riêng cho API base URL không
   - có cần secret/configmap riêng không
6. Chốt image strategy:
   - mỗi service một image repo
   - tag mặc định `main`
   - tag branch = commit SHA
7. Chốt deployment strategy:
   - namespace chung cho `dev`
   - namespace riêng cho `staging`
   - namespace riêng hoặc release riêng cho từng môi trường tạm developer
8. Chốt cách expose:
   - NodePort trực tiếp
   - hoặc Nginx/Ingress + NodePort cho ingress controller
9. Chốt cách resolve branch -> commit SHA trong Jenkins:
   - đọc từ Git refs
   - checkout branch rồi lấy `git rev-parse HEAD`
10. Viết bảng kiến trúc cuối cùng để cả nhóm dùng chung.

### File dự kiến tạo/sửa trong repo triển khai

- `docs/service-inventory.md`
- `docs/image-matrix.md`
- `docs/deployment-topology.md`
- `jenkins/README.md`
- `helm/` hoặc `deploy/helm/`

### Rủi ro cần xử lý

- Repo YAS có thể có nhiều module hơn mức cần demo.
- Một số service có thể thiếu Dockerfile production-ready.
- Nếu cố deploy toàn bộ hệ sinh thái một lần đầu, thời gian debug sẽ cao.

### Tiêu chí nghiệm thu phase 0

- Có danh sách rõ service nào bắt buộc.
- Có bảng image/tag/deploy mapping.
- Không còn tranh cãi về `main`, `latest`, commit SHA, namespace naming.

## Phase 1 - Dựng nền tảng Docker, Helm, K8S, Jenkins

### Mục tiêu

Có một nền tảng tối thiểu để deploy bản mặc định của YAS lên K8S bằng Helm trước khi làm CI/CD động.

### Đầu vào

- Kết quả phase 0
- Máy chủ Jenkins
- Cluster K8S

### Đầu ra

- Cluster chạy được
- Jenkins truy cập được cluster
- Helm chart deploy được bộ image mặc định

### Checklist công việc

1. Dựng cluster:
   - chọn `k3s`, `minikube`, hoặc 1 master + 1 worker
   - kiểm tra `kubectl get nodes`
2. Cài các công cụ cần thiết trên máy Jenkins:
   - Docker CLI hoặc build tool tương đương
   - `kubectl`
   - `helm`
   - JDK nếu build Java trực tiếp
3. Tạo credentials trong Jenkins:
   - GitHub token/SSH key
   - Docker Hub username/password hoặc token
   - kubeconfig hoặc service account cho cluster
4. Chuẩn hóa Docker build:
   - viết hoặc sửa `Dockerfile` cho các service thiếu
   - chuẩn hóa tag và naming
5. Tạo hoặc chuẩn hóa Helm chart:
   - `Chart.yaml`
   - `values.yaml`
   - `templates/deployment.yaml`
   - `templates/service.yaml`
   - `templates/configmap.yaml`
   - `templates/secret.yaml` nếu cần
6. Thiết kế values theo service:
   - `images.product.repository`
   - `images.product.tag`
   - `images.tax.repository`
   - `images.tax.tag`
   - ...
7. Tạo file values theo môi trường:
   - `values-common.yaml`
   - `values-dev.yaml`
   - `values-staging.yaml`
   - `values-developer-template.yaml`
8. Deploy thử bản mặc định toàn hệ thống bằng Helm.
9. Kiểm tra:
   - pods lên đủ
   - service nội bộ nói chuyện được
   - frontend/BFF truy cập được
10. Ghi lại các lỗi startup phổ biến và cách sửa.

### File dự kiến tạo/sửa trong repo triển khai

- `Dockerfile` cho từng service cần build
- `.dockerignore`
- `helm/yas/Chart.yaml`
- `helm/yas/values.yaml`
- `helm/yas/values-dev.yaml`
- `helm/yas/values-staging.yaml`
- `helm/yas/templates/*.yaml`
- `scripts/render-values.sh` hoặc script tương đương
- `docs/local-k8s-bootstrap.md`

### Tiêu chí nghiệm thu phase 1

- Có thể `helm install` hoặc `helm upgrade --install` bản mặc định thành công.
- Jenkins host chạy được `kubectl` và `helm` lên cluster đích.
- Các image mặc định trên Docker Hub đã sẵn sàng để dùng trong deploy sau này.

