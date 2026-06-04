# Phase 3: Jenkins CD Job `developer_build`

## Mục tiêu

Cho developer chọn branch theo service, rồi Jenkins deploy một môi trường test tạm trên K8S bằng Helm, đồng thời cung cấp địa chỉ truy cập kiểu `domain:NodePort`.

## Nguyên tắc thiết kế

1. Các service không override sẽ dùng tag mặc định `main`.
2. Service được override sẽ lấy commit SHA mới nhất từ branch được nhập.
3. Môi trường deploy phải tách biệt để không đè lên `dev` hoặc `staging`.
4. Toàn bộ cấu hình image/tag phải đi qua Helm values override.

## Thiết kế parameter khuyến nghị

### Cách đầy đủ, bám sát đề bài

- `DEPLOYER_ID`
- `RELEASE_SUFFIX`
- `NAMESPACE`
- `product_branch`
- `tax_branch`
- `inventory_branch`
- `cart_branch`
- `order_branch`
- `customer_branch`
- `rating_branch`
- `location_branch`
- `search_branch`
- `storefront_branch`
- `storefront_bff_branch`
- `backoffice_branch`
- `backoffice_bff_branch`

Mặc định tất cả giá trị là `main`.

### Cách tối giản hơn

- `TARGET_SERVICE`
- `TARGET_BRANCH`
- các service khác mặc định `main`

Nếu thời gian gấp, có thể làm cách này trước rồi mở rộng.

## Flow xử lý trong job

1. Nhận parameter.
2. Validate branch name.
3. Với mỗi service:
   - nếu branch là `main` thì tag = `main`
   - nếu branch khác `main` thì truy vấn commit SHA cuối của branch đó
4. Sinh file values override động.
5. Chọn namespace/release name theo developer.
6. Chạy `helm upgrade --install`.
7. Đợi rollout thành công.
8. Lấy NodePort hoặc ingress endpoint.
9. In ra URL test cho developer.

## Checklist công việc

1. Chọn strategy môi trường tạm:
   - một namespace cho mỗi developer
   - hoặc một release cho mỗi developer trong namespace chung
2. Chọn naming convention:
   - namespace: `yas-user-<id>`
   - release: `yas-<id>`
3. Viết script resolve branch -> tag:
   - branch `main` => `main`
   - branch khác => `git ls-remote` hoặc checkout branch rồi lấy SHA
4. Viết script generate values file tạm:
   - map tag cho từng service
   - map hostname/domain nếu có
5. Chuẩn hóa service expose:
   - NodePort cho storefront hoặc BFF entrypoint
   - có thể thêm host như `tax-user1.yas.local`
6. Cấu hình output trong Jenkins:
   - in release name
   - in namespace
   - in service NodePort
   - in hướng dẫn thêm `hosts`
7. Nếu rollout fail:
   - collect `kubectl get pods`
   - collect `kubectl describe`
   - collect logs pod lỗi
8. Lưu metadata deployment:
   - ai deploy
   - service nào override
   - branch nào
   - commit SHA nào
9. Nếu cần, gắn TTL bằng convention để cleanup sau này dễ hơn.

## File dự kiến tạo/sửa trong repo triển khai

- `jenkins/pipelines/developer_build.groovy`
- `jenkins/scripts/resolve-branch-tags.sh`
- `jenkins/scripts/generate-values.sh`
- `jenkins/scripts/deploy-helm.sh`
- `helm/yas/values-developer-template.yaml`
- `docs/developer-build.md`

## Dữ liệu đầu ra nên hiển thị trong Jenkins

- `Namespace: yas-user-anv`
- `Release: yas-anv`
- `Overridden services: tax`
- `Tax branch: dev_tax_service`
- `Tax image tag: a1b2c3d4`
- `Access URL: http://storefront-anv.yas.local:32080`
- `Hosts entry: <worker-node-ip> storefront-anv.yas.local`

## Tiêu chí nghiệm thu

1. Chạy job với tất cả branch = `main` thì deploy được môi trường mặc định.
2. Chạy job với `tax_branch=dev_tax_service` thì `tax-service` chạy image tag đúng bằng commit SHA mới nhất của branch đó.
3. Các service còn lại vẫn chạy tag `main`.
4. Developer truy cập được môi trường test qua `domain:NodePort`.

## Test cases cần chạy

1. Deploy full `main`.
2. Override 1 service.
3. Override nhiều service cùng lúc.
4. Nhập branch không tồn tại.
5. Deploy lại cùng developer ID để xem có upgrade ổn không.
6. Hai developer deploy song song để kiểm tra naming không đụng nhau.

## Rủi ro

- Branch parameter quá nhiều làm UI Jenkins khó dùng.
- Nếu frontend/BFF cần đồng bộ version với backend, override riêng lẻ có thể lỗi tích hợp.
- NodePort có thể xung đột nếu hardcode; nên để Kubernetes cấp động hoặc quản lý dải port rõ ràng.

