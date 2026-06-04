# Phase 6: Nâng Cao Service Mesh

## Mục tiêu

Bật mTLS giữa các service, quan sát topology bằng Kiali, cấu hình retry cho lỗi `500`, và dựng authorization policy để kiểm soát service-to-service communication.

## Công nghệ khuyến nghị

- Istio
- Kiali

## Phạm vi tối thiểu để đạt điểm phần này

1. Có mesh chạy trên namespace ứng dụng.
2. Có `PeerAuthentication` hoặc `DestinationRule` bật mTLS.
3. Có ít nhất một `AuthorizationPolicy`.
4. Có ít nhất một `VirtualService` thể hiện retry.
5. Có ảnh Kiali topology và test `curl` chứng minh policy hoạt động.

## Checklist công việc

1. Cài Istio control plane.
2. Label namespace để auto sidecar injection.
3. Redeploy workload để sidecar được inject.
4. Kiểm tra pod có 2 container trở lên.
5. Bật mTLS:
   - mesh-wide hoặc namespace-wide
6. Xác minh traffic nội bộ vẫn hoạt động sau khi bật mTLS.
7. Cài Kiali.
8. Sinh traffic để Kiali vẽ topology.
9. Chọn một đường gọi service để áp dụng retry.
10. Tạo `VirtualService` với retry cho lỗi `500`.
11. Chọn hai service để demo authorization policy:
   - một service được phép gọi
   - một service bị chặn
12. Tạo `AuthorizationPolicy`.
13. Chạy `kubectl exec ... curl ...` từ pod nguồn để test allow/deny.
14. Thu thập logs hoặc event chứng minh retry và deny.

## File dự kiến tạo/sửa

- `mesh/peer-authentication.yaml`
- `mesh/destination-rule.yaml`
- `mesh/virtual-service-retry.yaml`
- `mesh/authorization-policy.yaml`
- `mesh/kiali-access.md`
- `docs/service-mesh-test-plan.md`
- `docs/service-mesh-results.md`

## Kịch bản test khuyến nghị

### Test 1: mTLS

- Kiểm tra pod đã inject sidecar.
- Bật policy strict.
- Gọi service nội bộ và xác minh traffic vẫn thành công.

### Test 2: Retry

- Tạo tình huống service trả `500` có kiểm soát.
- Gọi request từ upstream.
- Xác minh có retry dựa trên logs hoặc metrics.

### Test 3: Authorization allow/deny

- Từ pod A gọi service B nếu được phép thì thành công.
- Từ pod C gọi service B nếu không được phép thì bị chặn.
- Ghi lại output `curl -v`.

## Tiêu chí nghiệm thu

1. Có manifest mesh đầy đủ.
2. Có screenshot Kiali topology.
3. Có bằng chứng retry.
4. Có bằng chứng policy allow/deny.
5. Có README hướng dẫn triển khai và test lại.

## Rủi ro

- YAS nhiều service nên mesh hóa toàn bộ có thể tăng độ khó debug.
- mTLS strict có thể làm hỏng traffic nếu một số workload không có sidecar.
- Cần sinh traffic đủ để Kiali hiển thị topology đẹp.

