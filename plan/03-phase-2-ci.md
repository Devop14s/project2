# Phase 2: Jenkins CI Build Và Push Image Theo Commit SHA

## Mục tiêu

Tự động build image từ branch bất kỳ, gắn tag là commit SHA cuối cùng của branch, rồi push lên Docker Hub.

## Đầu vào

- Dockerfiles đã chạy được
- Jenkins đã có credentials
- Repo YAS đã xác định danh sách service cần build

## Đầu ra

- Jenkins CI job hoặc multibranch pipeline
- Image trên Docker Hub có tag commit SHA
- Có log build rõ ràng và có thể truy vết commit -> image

## Thiết kế khuyến nghị

- Cách đơn giản và ít rủi ro:
  - mọi branch push lên sẽ build toàn bộ service deployable
  - tất cả image dùng cùng tag là `GIT_COMMIT_SHORT` hoặc full SHA
- Cách tối ưu hơn nhưng phức tạp:
  - detect service thay đổi theo path
  - chỉ build service affected
- Nên làm cách đơn giản trước để bảo đảm kịp deadline.

## Checklist công việc

1. Chọn kiểu Jenkins job:
   - Multibranch Pipeline nếu muốn tự động nhận branch mới
   - hoặc một pipeline nhận webhook và build branch tương ứng
2. Cấu hình GitHub webhook:
   - push event
   - Jenkins endpoint
3. Viết pipeline stages:
   - checkout source
   - xác định branch name
   - lấy commit SHA cuối
   - login Docker Hub
   - build image từng service
   - push image từng service
   - publish metadata
4. Chuẩn hóa biến:
   - `BRANCH_NAME`
   - `GIT_COMMIT`
   - `SHORT_SHA`
   - `DOCKERHUB_NAMESPACE`
5. Chuẩn hóa format image:
   - `docker.io/<namespace>/yas-product:<sha>`
   - `docker.io/<namespace>/yas-tax:<sha>`
6. Nếu muốn có default tag `main`:
   - khi branch là `main`, push thêm tag `main`
7. Thêm caching nếu cần:
   - `--cache-from`
   - buildkit
8. Tạo artifact metadata sau build:
   - file JSON hoặc text ghi branch, commit, danh sách image đã push
9. Nếu một service build fail:
   - fail fast toàn pipeline
   - hoặc đánh dấu service nào fail rồi dừng
10. Gửi thông báo sau build:
   - console log là tối thiểu
   - có thể thêm Slack/Telegram/email nếu nhóm dùng

## Gợi ý cấu trúc pipeline

1. `Prepare`
2. `Resolve Commit Metadata`
3. `Build Product`
4. `Build Tax`
5. `Build Inventory`
6. `...`
7. `Push Images`
8. `Publish Build Summary`

## File dự kiến tạo/sửa trong repo triển khai

- `Jenkinsfile`
- `jenkins/pipelines/ci.groovy`
- `jenkins/scripts/docker-login.sh`
- `jenkins/scripts/build-images.sh`
- `jenkins/scripts/push-images.sh`
- `docs/ci-flow.md`

## Dữ liệu cần lưu lại

- branch build
- commit SHA
- thời gian build
- image list
- digest sau push nếu lấy được

## Tiêu chí nghiệm thu

1. Push vào branch developer sẽ trigger Jenkins.
2. Jenkins build thành công và push image lên Docker Hub.
3. Tag image đúng bằng commit SHA của branch vừa build.
4. Có thể nhìn từ Jenkins log để biết commit nào sinh ra image nào.

## Test cases cần chạy

1. Push một commit mới lên branch `dev_tax_service`.
2. Xác minh Jenkins nhận đúng branch.
3. Xác minh tag image là SHA của commit mới nhất.
4. Xác minh image tồn tại trên Docker Hub.
5. Nếu push commit tiếp theo, phải sinh tag mới khác tag cũ.

## Rủi ro

- Build toàn bộ services có thể chậm.
- Một số service có thể cần secret/env đặc thù mới build được.
- Frontend image có thể cần build-time env khác runtime env.

