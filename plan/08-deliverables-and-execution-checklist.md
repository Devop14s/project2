# Deliverables, Timeline Và Checklist Thực Thi

## 1. Danh sách deliverables cuối cùng

### Bắt buộc

1. Jenkins CI pipeline build/push image theo commit SHA.
2. Jenkins job `developer_build`.
3. Jenkins cleanup job.
4. Môi trường K8S chạy được YAS.
5. Helm chart hoặc manifest triển khai.
6. Ảnh chụp và mô tả các bước cấu hình.
7. Báo cáo `.docx`.

### Nếu không làm nâng cao

1. Auto deploy `dev` từ `main`.
2. Release deploy `staging` từ tag version.

### Nếu làm nâng cao ArgoCD

1. Repo manifest hoặc thư mục manifest theo GitOps.
2. ArgoCD Applications.
3. Ảnh sync/health.

### Nếu làm nâng cao Service Mesh

1. YAML mTLS.
2. YAML authorization policy.
3. YAML retry.
4. Screenshot Kiali.
5. Test logs `curl`.

## 2. Checklist evidence phải chụp

1. Cluster node list: `kubectl get nodes`.
2. Jenkins credentials hoặc cấu hình pipeline.
3. Docker Hub repo và tags.
4. Jenkins job chạy CI thành công.
5. Jenkins job `developer_build` với input branch.
6. Helm release sau deploy.
7. Pod/service/nodeport sau deploy.
8. Truy cập ứng dụng từ browser hoặc `curl`.
9. Cleanup job trước và sau khi xóa.
10. Nếu có `dev`/`staging`: ảnh namespace và version tương ứng.
11. Nếu có ArgoCD: ảnh app `Healthy/Synced`.
12. Nếu có service mesh: ảnh Kiali, output `curl`, retry logs.

## 3. Bộ file nên có trong repo cuối

### Tối thiểu

- `Jenkinsfile` hoặc thư mục `jenkins/`
- `helm/` hoặc `deploy/helm/`
- `docs/`
- `scripts/`
- `README.md`

### Nên có thêm

- `docs/architecture.md`
- `docs/ci-cd-flow.md`
- `docs/runbook.md`
- `docs/troubleshooting.md`

## 4. Gợi ý chia việc cho 4 người

### Người 1

- Dựng Jenkins
- Viết CI pipeline
- Docker Hub integration

### Người 2

- Dựng K8S cluster
- Helm chart
- expose NodePort

### Người 3

- `developer_build`
- cleanup job
- `dev`/`staging`

### Người 4

- tài liệu
- evidence
- ArgoCD hoặc service mesh nâng cao

## 5. Trình tự thực hiện khuyến nghị theo ngày

### Ngày 1-2

- Clone repo
- kiểm kê service
- chốt kiến trúc
- chốt naming

### Ngày 3-5

- hoàn thiện Docker build
- dựng cluster
- dựng Helm chart
- deploy bản mặc định

### Ngày 6-8

- hoàn thiện Jenkins CI
- push image theo commit SHA
- test với branch developer

### Ngày 9-11

- hoàn thiện `developer_build`
- hoàn thiện cleanup job
- test NodePort/domain/hosts

### Ngày 12-14

- hoàn thiện `dev`
- hoàn thiện `staging`
- nếu làm nâng cao thì chuyển sang ArgoCD hoặc service mesh

### Ngày 15-17

- chụp evidence
- viết báo cáo
- rehearsal demo

## 6. Definition of Done cho toàn đồ án

1. Một commit mới trên branch developer sinh ra image mới có tag commit SHA.
2. Jenkins có thể deploy môi trường tạm với một service override theo branch developer.
3. Developer truy cập được môi trường test bằng `domain:NodePort`.
4. Jenkins có thể xóa môi trường đó.
5. `dev` và `staging` chạy đúng theo flow đã chọn.
6. Báo cáo có đủ ảnh, mô tả, kiến trúc, và bằng chứng nghiệm thu.

## 7. Những lỗi thường gặp cần chuẩn bị trước

1. Docker build fail do thiếu context hoặc thiếu file `.dockerignore`.
2. Jenkins không push được Docker Hub do credential sai.
3. Helm values map sai tên image/tag.
4. Pod crash vì thiếu secret hoặc env.
5. Frontend/BFF gọi sai hostname nội bộ.
6. NodePort mở đúng nhưng app không bind đúng port trong container.
7. Cleanup xóa release nhưng namespace còn finalizer.
8. ArgoCD hoặc Istio gây thêm lớp debug khó hơn, chỉ nên làm sau khi baseline đã ổn.

