# Phase 5: Nâng Cao ArgoCD

## Mục tiêu

Thay phần CD trực tiếp từ Jenkins bằng mô hình GitOps: Jenkins build image rồi cập nhật manifest/Helm values trong repo triển khai, ArgoCD tự đồng bộ xuống cluster.

## Khi nào nên chọn hướng này

- Nhóm muốn lấy điểm nâng cao.
- Có đủ thời gian để tách repo manifest và debug ArgoCD.
- Muốn kiến trúc sạch hơn, dễ audit thay đổi deployment hơn.

## Kiến trúc khuyến nghị

### Repo ứng dụng

- chứa source YAS
- Jenkins build image từ đây

### Repo manifest

- chứa Helm chart hoặc K8S manifest
- Jenkins cập nhật tag image vào repo này
- ArgoCD watch repo này

## Checklist công việc

1. Tạo repo manifest riêng hoặc thư mục manifest tách biệt.
2. Chuyển Helm chart sang repo manifest nếu cần.
3. Thiết kế cấu trúc:
   - `apps/dev/`
   - `apps/staging/`
   - `helm/yas/`
4. Cài ArgoCD lên cluster.
5. Tạo ArgoCD Applications cho:
   - `yas-dev`
   - `yas-staging`
6. Cấu hình Jenkins sau build:
   - sửa values của repo manifest
   - commit thay đổi tag image
   - push lên Git
7. Kiểm tra ArgoCD tự sync.
8. Bật auto-sync cho `dev`.
9. Chọn manual sync hoặc gated sync cho `staging` nếu muốn kiểm soát.
10. Ghi lại toàn bộ flow và screenshot.

## File dự kiến tạo/sửa trong repo manifest

- `helm/yas/Chart.yaml`
- `helm/yas/values-dev.yaml`
- `helm/yas/values-staging.yaml`
- `argocd/app-dev.yaml`
- `argocd/app-staging.yaml`
- `README.md`

## File dự kiến tạo/sửa trong repo Jenkins/app

- `jenkins/pipelines/dev_gitops.groovy`
- `jenkins/pipelines/staging_gitops.groovy`
- `jenkins/scripts/update-manifest-repo.sh`
- `docs/argocd-flow.md`

## Tiêu chí nghiệm thu

1. Commit vào `main` làm Jenkins build xong và cập nhật repo manifest.
2. ArgoCD phát hiện thay đổi và sync xuống namespace `dev`.
3. Release tag làm Jenkins cập nhật manifest `staging`.
4. ArgoCD sync `staging` đúng version.

## Evidence cần chuẩn bị

- Screenshot Jenkins build xong commit manifest.
- Screenshot ArgoCD app status `Synced` và `Healthy`.
- Git history trong repo manifest cho thấy image tag được cập nhật.

## Rủi ro

- Tách repo manifest làm tăng khối lượng chuẩn bị.
- Cần quản lý credentials Git cho Jenkins và ArgoCD.
- Nếu chart chưa sạch, ArgoCD sẽ lộ nhiều drift hơn CD trực tiếp.

