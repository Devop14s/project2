# Phân Tích Yêu Cầu

## 1. Kết quả cần đạt theo đề bài

### Bắt buộc

1. Có môi trường Kubernetes chạy được YAS.
2. Có pipeline CI build image từ branch của developer.
3. Tag image của branch phải là commit id cuối cùng của branch đó.
4. Có Jenkins job `developer_build` cho phép nhập branch để deploy bản test.
5. Có Jenkins job xóa deployment tạm của developer.
6. Nếu không làm nâng cao thì có thêm luồng `dev` và `staging` bằng Jenkins.

### Nâng cao

1. Dùng ArgoCD để handle `dev` và `staging`.
2. Dùng service mesh để bật mTLS, quan sát topology, retry, authorization policy.

### Deliverables

1. Báo cáo `.docx`.
2. Ảnh chụp các bước cấu hình.
3. Evidence cho deploy, test, topology, policy, retry.

## 2. Diễn giải kỹ từng yêu cầu

### Yêu cầu 1: image mặc định

- Ý nghĩa thực tế:
  - hệ thống phải có một bộ image "chuẩn" để chạy mặc định
  - tag chuẩn là `main` hoặc `latest`
- Việc cần chốt:
  - dùng `main` hay `latest` làm tag mặc định
  - đặt tên image repo trên Docker Hub theo service như thế nào
- Khuyến nghị:
  - dùng `main` làm tag mặc định, không dùng `latest` cho môi trường cần truy vết

### Yêu cầu 2: cluster K8S

- Có thể dùng:
  - 1 control-plane + 1 worker thật
  - Minikube
  - K3s/K3d
- Khuyến nghị để làm nhanh:
  - local/lab: `k3s` hoặc `minikube`
  - nếu có 2 VM: dựng 1 control-plane + 1 worker để bám đề hơn
- Hệ quả:
  - cần chuẩn bị ingress hoặc NodePort
  - cần chuẩn bị persistent storage tối thiểu nếu một số service yêu cầu

### Yêu cầu 3: CI build theo branch

- Trigger:
  - push lên branch của developer
- Output:
  - image được push lên Docker Hub
  - tag là commit SHA
- Điểm phải quyết định:
  - build toàn bộ service hay chỉ service bị ảnh hưởng
  - nếu build chọn lọc thì cần logic detect path thay đổi
- Khuyến nghị:
  - giai đoạn đầu build toàn bộ image deployable với cùng tag commit SHA
  - tối ưu chọn lọc chỉ làm nếu thời gian dư

### Yêu cầu 4: job `developer_build`

- Job phải cho developer chọn branch muốn deploy.
- Ví dụ đề bài cho thấy có thể override branch theo từng service.
- Suy ra job cần:
  - danh sách parameter theo service, hoặc
  - ít nhất parameter chọn service + branch
- Khuyến nghị để bám đề rõ nhất:
  - mỗi service có một parameter branch
  - giá trị mặc định là `main`
  - service nào cần test thì nhập branch của developer
- Job phải tự:
  - tra commit SHA mới nhất của branch đã nhập
  - map service -> image tag tương ứng
  - render Helm values
  - deploy sang namespace/prefix riêng

### Yêu cầu 5: cleanup job

- Cần xóa môi trường do `developer_build` tạo ra.
- Job nên nhận:
  - namespace
  - release name
  - developer id hoặc ticket id
- Nên xóa:
  - Helm release
  - service NodePort
  - ingress nếu có
  - namespace tạm nếu mỗi developer có namespace riêng

### Yêu cầu 6: `dev` và `staging`

- Nếu không làm nâng cao:
  - Jenkins trực tiếp deploy `dev`
  - Jenkins trực tiếp deploy `staging`
- `dev`:
  - auto deploy khi `main` thay đổi
- `staging`:
  - deploy theo release tag như `v1.2.3`
- Hệ quả:
  - Helm values cho mỗi môi trường phải tách riêng
  - image tag strategy phải hỗ trợ `main` và semantic version

## 3. Các điểm mơ hồ cần chốt sớm

1. "1 image cho tất cả các service" là câu mơ hồ.
   - Cách hiểu nên dùng: một bộ image mặc định cho tất cả service, không phải một container duy nhất chứa cả hệ thống.
2. `developer_build` có cần override branch cho tất cả service hay chỉ một service.
   - Đề ví dụ theo từng service, nên nên thiết kế theo từng service.
3. YAS có những service nào thật sự cần build/deploy.
   - Cần kiểm kê repo thật để biết service nào là runtime service, service nào chỉ là tool.
4. Có cần observability trong phần bắt buộc không.
   - Không, đề bài nói có thể bỏ Grafana/Prometheus.
5. Có cần domain thật không.
   - Không, chỉ cần `domain:NodePort` và developer tự sửa file `hosts`.

## 4. Quyết định kiến trúc nên chốt trước khi làm

1. Dùng Jenkins là công cụ trung tâm cho CI/CD.
2. Dùng Helm để triển khai vì đề bài nêu rõ Helm.
3. Dùng 1 chart umbrella hoặc 1 chart có map image tags theo service.
4. Dùng namespace riêng cho:
   - `dev`
   - `staging`
   - môi trường tạm của developer
5. Dùng naming convention rõ ràng:
   - namespace: `yas-dev`, `yas-staging`, `yas-pr-<name>` hoặc `yas-user-<name>`
   - release: `yas`, `yas-staging`, `yas-<developer>`
6. Dùng Docker Hub repo naming cố định:
   - `dockerhub-user/yas-product`
   - `dockerhub-user/yas-tax`
   - ...

## 5. Danh sách đầu việc lớn suy ra từ đề bài

1. Clone và kiểm kê source YAS.
2. Chuẩn hóa Dockerfiles/build commands.
3. Chuẩn hóa Helm chart + values override.
4. Dựng cluster + Jenkins + credentials.
5. Dựng CI build & push image.
6. Dựng CD deploy job cho developer.
7. Dựng cleanup job.
8. Dựng luồng `dev` và `staging`.
9. Nếu làm nâng cao: tách manifest repo + ArgoCD.
10. Nếu làm nâng cao: cài Istio/Kiali + policy/test.
11. Chuẩn bị báo cáo và bằng chứng nghiệm thu.

## 6. Tiêu chí hoàn thành tối thiểu

- Có thể chạy job CI từ một branch bất kỳ và thấy image mới trên Docker Hub với tag là commit SHA.
- Có thể chạy `developer_build` và deploy được bản test với ít nhất một service override từ branch riêng.
- Có thể truy cập môi trường test qua `domain:NodePort`.
- Có thể chạy cleanup job và xóa deployment tạm.
- Nếu không làm nâng cao: có auto deploy `dev` và release deploy `staging`.

