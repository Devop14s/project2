# Implementation Blueprint

## 1. Mục tiêu của blueprint này

File này trả lời ở mức triển khai thực tế:

1. Tạo file nào trước.
2. Script nào viết trước để giảm phụ thuộc vòng.
3. Jenkinsfile nên được tách ra sao.
4. Helm chart nên có khung gì để support `main`, commit SHA, `developer_build`, `dev`, `staging`.

## 2. Giả định triển khai

### Giả định tối thiểu

- Nhóm dùng Jenkins làm CI/CD.
- Nhóm dùng Docker Hub làm registry.
- Nhóm dùng Helm để deploy lên K8S.
- Nhóm chưa tách manifest repo riêng trong giai đoạn bắt buộc.

### Giả định về repo

Vì hiện chưa có source YAS trong workspace, blueprint này dùng cấu trúc repo triển khai khuyến nghị như sau:

```text
yas/
  Jenkinsfile
  jenkins/
    pipelines/
    scripts/
  scripts/
  helm/
    yas/
  docs/
```

Nếu repo YAS hiện tại khác cấu trúc trên, ưu tiên giữ nguyên source tree của repo gốc và chỉ thêm các thư mục `jenkins/`, `helm/`, `docs/`.

## 3. Thứ tự tạo file khuyến nghị

## Bước 1 - Tạo khung chart và values trước

### Tạo trước các file sau

1. `helm/yas/Chart.yaml`
2. `helm/yas/values.yaml`
3. `helm/yas/values-dev.yaml`
4. `helm/yas/values-staging.yaml`
5. `helm/yas/values-developer-template.yaml`
6. `helm/yas/templates/_helpers.tpl`
7. `helm/yas/templates/deployment.yaml`
8. `helm/yas/templates/service.yaml`
9. `helm/yas/templates/configmap.yaml`
10. `helm/yas/templates/ingress.yaml` nếu cần

### Lý do tạo trước

- Jenkins CD chỉ ổn khi trước đó Helm deploy thủ công đã chạy được.
- Mọi script `developer_build` sau này đều dựa trên values override của Helm.

## Bước 2 - Tạo script shell nền tảng

### Tạo tiếp các file sau

1. `jenkins/scripts/common.sh`
2. `jenkins/scripts/resolve-branch-tags.sh`
3. `jenkins/scripts/build-images.sh`
4. `jenkins/scripts/push-images.sh`
5. `jenkins/scripts/generate-values.sh`
6. `jenkins/scripts/deploy-helm.sh`
7. `jenkins/scripts/cleanup-release.sh`
8. `jenkins/scripts/smoke-test.sh`

### Lý do

- Không nên nhét toàn bộ logic vào Jenkinsfile.
- Jenkinsfile chỉ nên orchestration, còn business logic và shell flow phải nằm trong script tái sử dụng.

## Bước 3 - Tạo pipeline Jenkins

### Tạo các file sau

1. `Jenkinsfile`
2. `jenkins/pipelines/ci.groovy`
3. `jenkins/pipelines/developer_build.groovy`
4. `jenkins/pipelines/developer_cleanup.groovy`
5. `jenkins/pipelines/dev_cd.groovy`
6. `jenkins/pipelines/staging_release.groovy`

### Lý do

- Khi script nền đã có, pipeline chỉ còn việc gọi đúng file đúng stage.
- Dễ test từng script local trước khi đưa vào Jenkins.

## Bước 4 - Tạo tài liệu chạy và runbook

### Tạo các file sau

1. `README.md`
2. `docs/service-inventory.md`
3. `docs/deployment-topology.md`
4. `docs/ci-flow.md`
5. `docs/developer-build.md`
6. `docs/developer-cleanup.md`
7. `docs/dev-environment.md`
8. `docs/staging-release.md`
9. `docs/troubleshooting.md`

## 4. File tree khuyến nghị

```text
yas/
  Jenkinsfile
  README.md
  docs/
    service-inventory.md
    image-matrix.md
    deployment-topology.md
    ci-flow.md
    developer-build.md
    developer-cleanup.md
    dev-environment.md
    staging-release.md
    troubleshooting.md
  jenkins/
    pipelines/
      ci.groovy
      developer_build.groovy
      developer_cleanup.groovy
      dev_cd.groovy
      staging_release.groovy
    scripts/
      common.sh
      resolve-branch-tags.sh
      build-images.sh
      push-images.sh
      generate-values.sh
      deploy-helm.sh
      cleanup-release.sh
      smoke-test.sh
  helm/
    yas/
      Chart.yaml
      values.yaml
      values-dev.yaml
      values-staging.yaml
      values-developer-template.yaml
      templates/
        _helpers.tpl
        deployment.yaml
        service.yaml
        configmap.yaml
        ingress.yaml
        secret.yaml
        namespace.yaml
```

## 5. Trình tự thực hiện thực tế theo dependency

## Giai đoạn A - Làm cho Helm chạy thủ công trước

1. Tạo `Chart.yaml`.
2. Tạo `values.yaml` với image repo/tag mặc định.
3. Tạo `deployment.yaml` chỉ cho 1 service mẫu trước, ví dụ `tax`.
4. Tạo `service.yaml` cho service mẫu.
5. `helm template` để kiểm tra render.
6. `helm install` bản tối thiểu.
7. Khi service mẫu chạy ổn, mở rộng sang toàn bộ service.

### Vì sao nên làm theo cách này

- Nếu làm đủ mọi service ngay từ đầu, lỗi render và lỗi values sẽ khó truy vết.
- Nên chứng minh flow `1 service -> nhiều service`.

## Giai đoạn B - Làm CI build độc lập với Jenkins trước

1. Viết `build-images.sh`.
2. Chạy local với biến môi trường giả.
3. Viết `push-images.sh`.
4. Chạy local hoặc runner tương đương.
5. Khi script chạy ổn mới bọc vào `ci.groovy`.

## Giai đoạn C - Làm deploy script độc lập với Jenkins trước

1. Viết `resolve-branch-tags.sh`.
2. Viết `generate-values.sh`.
3. Viết `deploy-helm.sh`.
4. Test local bằng cách export param và chạy từng script.
5. Sau đó mới nối vào `developer_build.groovy`.

## Giai đoạn D - Thêm cleanup và môi trường chuẩn

1. Viết `cleanup-release.sh`.
2. Tạo `developer_cleanup.groovy`.
3. Tạo `dev_cd.groovy`.
4. Tạo `staging_release.groovy`.

## 6. Blueprint cho từng file quan trọng

## A. `jenkins/scripts/common.sh`

### Viết file này đầu tiên

File này chứa:

- `set -euo pipefail`
- hàm log
- hàm validate env
- hàm chuẩn hóa tên branch
- hàm build tên image
- hàm build namespace/release name

### Mục đích

Tránh copy logic lặp lại giữa CI, deploy, cleanup.

## B. `resolve-branch-tags.sh`

### Viết file này thứ hai trong nhóm script

File này phải:

1. Nhận map service -> branch.
2. Nếu branch là `main` thì trả tag `main`.
3. Nếu branch khác `main` thì truy Git để lấy SHA cuối.
4. Sinh ra file output dạng env hoặc YAML trung gian.

### Đầu ra khuyến nghị

- `work/branch-tags.env`
- hoặc `work/branch-tags.yaml`

## C. `generate-values.sh`

### Viết sau `resolve-branch-tags.sh`

File này phải:

1. Đọc template values.
2. Gắn đúng `repository` và `tag` cho từng service.
3. Gắn hostname, namespace, release metadata.
4. Xuất ra `work/generated-values.yaml`.

## D. `deploy-helm.sh`

### Viết sau khi `generated-values.yaml` đã có

File này phải:

1. Bảo đảm namespace tồn tại.
2. Chạy `helm upgrade --install`.
3. Chờ rollout.
4. Thu thập `kubectl get svc`, `kubectl get pods`.
5. In ra endpoint cuối.

## E. `cleanup-release.sh`

### Viết sau `deploy-helm.sh`

File này phải:

1. Uninstall release.
2. Chờ resource biến mất.
3. Xóa namespace nếu cần.
4. Log resource còn sót.

## 7. Blueprint cho `Jenkinsfile`

### Khuyến nghị dùng 1 Jenkinsfile dispatcher

Thay vì tạo nhiều job freestyle, nên dùng một `Jenkinsfile` trung tâm để route theo biến `JOB_KIND` hoặc theo từng Jenkins job trỏ vào từng pipeline script.

### Hai cách tổ chức

#### Cách 1: mỗi job dùng cùng `Jenkinsfile`

- Jenkins job truyền biến `PIPELINE_TARGET`
- `Jenkinsfile` load file tương ứng trong `jenkins/pipelines/`

#### Cách 2: mỗi job trỏ thẳng vào script pipeline riêng

- dễ hiểu hơn cho nhóm sinh viên
- ít logic động hơn

### Khuyến nghị

Dùng cách 2 để dễ demo và dễ debug.

## 8. Blueprint cho Helm chart

### Cấu trúc values nên theo service map

Không nên hardcode mỗi service ở nhiều chỗ rời rạc. Nên dùng một map thống nhất:

```yaml
services:
  tax:
    enabled: true
    image:
      repository: docker.io/org/yas-tax
      tag: main
    service:
      port: 8080
    env: []
```

### Lợi ích

- dễ generate values tự động
- dễ override tag theo service
- dễ tái dùng cho `dev`, `staging`, `developer_build`

## 9. Blueprint cho naming convention

### Release

- `yas-dev`
- `yas-staging`
- `yas-<developer-id>`

### Namespace

- `yas-dev`
- `yas-staging`
- `yas-user-<developer-id>`

### Host

- `storefront-dev.yas.local`
- `storefront-staging.yas.local`
- `storefront-<developer-id>.yas.local`

## 10. Blueprint cho artifacts sinh ra trong pipeline

### CI

- `work/image-metadata.json`
- `work/image-list.txt`

### Deploy

- `work/branch-tags.env`
- `work/generated-values.yaml`
- `work/deploy-summary.txt`

### Cleanup

- `work/cleanup-summary.txt`

## 11. Thứ tự build nhanh nhất để ra demo sớm

1. Helm deploy được 1 service mẫu.
2. Helm deploy được full bản `main`.
3. CI push được image tag SHA.
4. `developer_build` override được 1 service.
5. Cleanup xóa được môi trường đó.
6. Cuối cùng mới làm `dev` và `staging`.

## 12. Definition of Ready trước khi code pipeline

Chỉ nên bắt đầu viết Jenkins pipeline khi đã có đủ:

1. Ít nhất một service build image thành công thủ công.
2. Ít nhất một service deploy Helm thành công thủ công.
3. Docker Hub repo đã tạo sẵn.
4. Jenkins credential names đã chốt.
5. Namespace/release naming đã chốt.

