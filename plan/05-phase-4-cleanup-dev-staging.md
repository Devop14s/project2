# Phase 4: Cleanup Job Và Luồng `dev`/`staging`

## A. Cleanup job cho môi trường developer

### Mục tiêu

Xóa sạch deployment tạm do `developer_build` tạo ra để tránh tốn tài nguyên và tránh xung đột tên.

### Checklist công việc

1. Chốt resource scope cần xóa:
   - Helm release
   - namespace tạm nếu dùng namespace riêng
   - PVC/PV tạm nếu có
   - ingress/service/nodeport liên quan
2. Chọn parameter cho cleanup job:
   - `DEPLOYER_ID`
   - `NAMESPACE`
   - `RELEASE_NAME`
   - `FORCE_DELETE_NAMESPACE`
3. Viết logic:
   - tìm release
   - `helm uninstall`
   - chờ resource terminate
   - xóa namespace nếu cần
4. In kết quả rõ ràng:
   - release nào đã xóa
   - namespace nào đã xóa
   - resource nào còn kẹt
5. Nếu muốn đẹp hơn:
   - thêm hyperlink tới job deploy tương ứng
   - thêm link tới dashboard Jenkins/K8S

### File dự kiến tạo/sửa

- `jenkins/pipelines/developer_cleanup.groovy`
- `jenkins/scripts/cleanup-release.sh`
- `docs/developer-cleanup.md`

### Tiêu chí nghiệm thu

- Cleanup job xóa được môi trường tạm không lỗi.
- Chạy lại `developer_build` sau cleanup không bị xung đột tài nguyên cũ.

## B. Luồng `dev`

### Mục tiêu

Khi `main` thay đổi, hệ thống tự động build và deploy đè vào namespace `dev`.

### Checklist công việc

1. Tạo pipeline trigger khi branch `main` có commit mới.
2. Reuse CI build logic:
   - build image
   - push tag `main`
   - có thể push cả SHA để truy vết
3. Tạo CD stage:
   - deploy vào `yas-dev`
   - dùng `values-dev.yaml`
4. Sau deploy:
   - rollout status
   - smoke test endpoint
5. Nếu fail:
   - dừng pipeline
   - lưu log rollout

### File dự kiến tạo/sửa

- `jenkins/pipelines/dev_cd.groovy`
- `helm/yas/values-dev.yaml`
- `docs/dev-environment.md`

### Tiêu chí nghiệm thu

- Commit vào `main` làm `dev` được cập nhật tự động.
- Namespace `yas-dev` luôn phản ánh bản mới nhất của `main`.

## C. Luồng `staging`

### Mục tiêu

Deploy môi trường `staging` theo release tag như `v1.2.3`.

### Checklist công việc

1. Chọn trigger:
   - Git tag `v*`
   - hoặc branch `rc_*`
2. Chuẩn hóa semantic versioning cho nhóm.
3. Viết pipeline:
   - xác định release version
   - build/push image với tag version
   - deploy vào `yas-staging`
4. Dùng values riêng cho staging:
   - resource requests khác
   - replica khác nếu cần
5. Thêm approval thủ công trước khi deploy nếu muốn an toàn hơn.
6. Thêm smoke test sau deploy.

### File dự kiến tạo/sửa

- `jenkins/pipelines/staging_release.groovy`
- `helm/yas/values-staging.yaml`
- `docs/staging-release.md`

### Tiêu chí nghiệm thu

- Tạo tag `v1.2.3` sẽ build được image `v1.2.3`.
- Namespace `yas-staging` chạy đúng version vừa release.

## D. Thứ tự triển khai khuyến nghị trong phase 4

1. Làm cleanup job trước.
2. Làm auto deploy `dev`.
3. Làm release deploy `staging`.
4. Cuối cùng mới thêm tối ưu như approval, notification, rollback.

