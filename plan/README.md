# Plan Triển Khai Đồ Án CD Cho YAS

## Mục tiêu của bộ plan

Thư mục này tách yêu cầu đề bài thành các phase nhỏ, có thứ tự thực hiện rõ ràng, để nhóm có thể chuẩn bị và triển khai dần mà không bị thiếu hạng mục.

## Phạm vi đã phân tích

- Bắt buộc:
  - K8S cluster
  - CI build image theo branch với tag là commit id
  - Jenkins job `developer_build`
  - Jenkins job xóa môi trường deploy của developer
- Tùy chọn theo hướng thường:
  - Job tự động deploy `dev`
  - Job release deploy `staging`
- Nâng cao:
  - ArgoCD
  - Service Mesh với Istio/Kiali/mTLS/retry/authz
- Deliverables:
  - Báo cáo `.docx`
  - Screenshot, logs, topology, test evidence

## Giả định quan trọng

1. Workspace hiện chỉ có file yêu cầu, chưa có source code YAS được clone về.
2. Plan này bám theo đề bài và kiến trúc YAS nêu trong tài liệu, chưa bám theo cấu trúc file thực tế của repo `nashtech-garage/yas`.
3. Cần xác nhận sớm cách hiểu của yêu cầu "1 image cho tất cả các service". Cách triển khai hợp lý nhất là:
   - Mỗi service có image riêng.
   - Tất cả service mặc định deploy bằng tag `main` hoặc `latest`.
   - Khi branch của developer thay đổi, build ra tag theo commit SHA cho các image liên quan.
4. Nếu muốn đơn giản hóa logic, nên build toàn bộ image deployable của monorepo bằng cùng một tag commit SHA cho mỗi lần CI trên branch.
5. Phần bắt buộc không cần dựng stack observability Grafana/Prometheus.

## Thứ tự đọc khuyến nghị

1. `01-requirements-analysis.md`
2. `02-phase-0-1-discovery-foundation.md`
3. `03-phase-2-ci.md`
4. `04-phase-3-cd-developer-build.md`
5. `05-phase-4-cleanup-dev-staging.md`
6. `06-phase-5-advanced-argocd.md`
7. `07-phase-6-advanced-service-mesh.md`
8. `08-deliverables-and-execution-checklist.md`
9. `09-implementation-blueprint.md`
10. `10-jenkinsfile-helm-script-skeletons.md`

## Roadmap tổng quát

- Phase 0: Làm rõ yêu cầu, kiểm kê repo, chốt chiến lược image/tag/branch.
- Phase 1: Dựng cluster, chuẩn hóa Docker build, tách Helm/K8S manifest.
- Phase 2: Dựng Jenkins CI build và push image theo commit SHA.
- Phase 3: Dựng Jenkins CD job `developer_build` với branch override theo service.
- Phase 4: Dựng job cleanup, rồi mở rộng `dev` và `staging`.
- Phase 5: Nếu làm nâng cao, chuyển phần đồng bộ deployment sang ArgoCD.
- Phase 6: Nếu làm nâng cao, bổ sung Istio/Kiali/mTLS/retry/authz.
- Phase 7: Thu thập evidence, viết báo cáo, rehearsal demo.

## Cách dùng bộ plan này

- Mỗi phase đều có:
  - mục tiêu
  - đầu vào
  - đầu ra
  - checklist công việc nhỏ
  - file dự kiến cần tạo/sửa
  - tiêu chí nghiệm thu
- Hai file blueprint cuối dùng để bắt đầu tạo file thật:
  - `09-implementation-blueprint.md`: thứ tự tạo file và thứ tự triển khai
  - `10-jenkinsfile-helm-script-skeletons.md`: khung nội dung kỹ thuật cho Jenkins, script, Helm
- Nếu nhóm chia người:
  - 1 người lo Jenkins/CI
  - 1 người lo Helm/K8S
  - 1 người lo Docker/image strategy
  - 1 người lo tài liệu/evidence/nâng cao

