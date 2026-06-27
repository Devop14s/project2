# Hướng Dẫn Từng Bước Thực Hiện Đồ Án 2 (Yêu cầu 1 đến 6)

Tài liệu này hướng dẫn chi tiết cách cài đặt, cấu hình và chạy thực tế toàn bộ quy trình CI/CD cho dự án YAS Microservices từ Yêu cầu 1 đến Yêu cầu 6.

---

## GIAI ĐOẠN 1: CHUẨN BỊ MÔI TRƯỜNG DƯỚI LOCAL

Trước khi làm việc với Jenkins, máy tính của bạn cần sẵn sàng các công cụ cốt lõi.

### 1. Bật Docker Desktop & Kubernetes (K8s)

1. Mở ứng dụng **Docker Desktop**.
2. Nhấp vào biểu tượng **Settings (Răng cưa)** ở góc trên bên phải.
3. Chọn mục **Kubernetes** từ menu bên trái.
4. Tích chọn **Enable Kubernetes** và nhấp **Apply & restart**. Đợi 3-5 phút cho đến khi biểu tượng K8s ở góc dưới bên trái chuyển sang màu xanh lá cây.
5. Mở terminal (PowerShell) và gõ lệnh sau để kiểm tra:
   ```powershell
   kubectl get nodes
   ```

   * *Kết quả thành công:* Hiện tên node `docker-desktop` với trạng thái `Ready`.

### 2. Cài đặt Helm

* Cài đặt qua PowerShell (sử dụng Chocolatey hoặc Scoop):
  ```powershell
  choco install kubernetes-helm
  # Hoặc: scoop install helm
  ```
* Kiểm tra phiên bản cài đặt thành công:
  ```powershell
  helm version
  ```

---

## GIAI ĐOẠN 2: CẤU HÌNH JENKINS SERVER

Bạn cần có một Jenkins đang chạy (có thể chạy dạng Docker container trên máy local).

### 1. Cài đặt các Công cụ trên Jenkins Agent (hoặc máy chạy Jenkins)

Đảm bảo máy chạy Jenkins đã được cài sẵn các CLI: **`git`**, **`docker`**, **`kubectl`**, và **`helm`**.

### 2. Tạo các Credentials (Thông tin xác thực) trên Jenkins

Vào giao diện **Jenkins** -> **Manage Jenkins** -> **Credentials** -> **System** -> **Global credentials** và thêm 2 credentials sau:

1. **Thông tin đăng nhập Docker Hub:**
   * *Kind:* Username with password
   * *ID:* **`dockerhub-creds`**
   * *Username:* Tài khoản Docker Hub của bạn
   * *Password:* Personal Access Token hoặc mật khẩu Docker Hub của bạn.
2. **File cấu hình Kubernetes (Kubeconfig):**
   * *Kind:* Secret file
   * *ID:* **`kubeconfig-file`**
   * *File:* Upload file cấu hình kubeconfig của bạn lên.
     *(File này nằm tại thư mục cá nhân trên Windows của bạn: `C:\Users\<Tên_User>\.kube\config`).*

### 3. Thiết lập biến môi trường toàn cục

Vào **Manage Jenkins** -> **Configure System** -> **Global properties** -> Tích chọn **Environment variables** và thêm biến:

* Name: `DOCKERHUB_NAMESPACE`
* Value: *Tên tài khoản (username) Docker Hub của bạn.*

---

## GIAI ĐOẠN 3: TẠO CÁC JOB PIPELINE TRÊN JENKINS

Với mỗi mục tiêu trong đồ án, bạn sẽ tạo các Jenkins Job tương ứng trỏ vào file cấu hình có sẵn trong mã nguồn.

### Cách cấu hình chung cho các Job:

* Loại Job: **Pipeline**.
* Tại mục **Pipeline**, chọn: **Pipeline script from SCM**.
* *SCM:* Git.
* *Repository URL:* Đường dẫn Git repository CD của bạn (chính là repo chứa file này).
* *Branch Specifier:* `*/main`.
* *Script Path:* Điền **`Jenkinsfile`** (Chúng ta dùng chung một Jenkinsfile làm dispatcher trung tâm, phân biệt bằng biến môi trường `PIPELINE_TARGET`).

### Danh sách 5 Job cần tạo và cấu hình tham số cụ thể:

#### 1. Job CI tự động: `yas-ci`

* **Mục đích (Yêu cầu 3):** Tự động build và push image của nhánh khi dev commit.
* **Cấu hình tham số (Build with Parameters):**
  * Thêm biến Environment hoặc Parameter:
    * `PIPELINE_TARGET` = `ci`
    * `SERVICE_CATALOG` = `release-baseline` (Sử dụng danh mục 12 service cốt lõi để chạy ổn định đợt đầu).

#### 2. Job Deploy thử nghiệm của Developer: `yas-developer-build`

* **Mục đích (Yêu cầu 4):** Cho phép dev deploy bản mix giữa nhánh cá nhân và nhánh chính `main`.
* **Cấu hình tham số:**
  * `PIPELINE_TARGET` = `developer_build`
  * Thêm các tham số dạng **String Parameter** tương ứng với các service cần hỗ trợ override (ví dụ: `tax_BRANCH` mặc định là `main`, `product_BRANCH` mặc định là `main`...).
  * *Lưu ý:* Jenkinsfile đã tự động đọc danh sách này, bạn chỉ cần điền tên nhánh muốn test khi bắt đầu bấm chạy.

#### 3. Job Dọn dẹp Namespace: `yas-developer-cleanup`

* **Mục đích (Yêu cầu 5):** Xoá môi trường test của dev sau khi sử dụng xong.
* **Cấu hình tham số:**
  * `PIPELINE_TARGET` = `developer_cleanup`
  * `DEVELOPER_ID` = Tham số dạng String (để nhập tên namespace cần xoá, ví dụ `dev-a`).

#### 4. Job CD môi trường Dev chung: `yas-dev-cd`

* **Mục đích (Yêu cầu 6a):** Tự động deploy đè bản mới nhất của `main` lên môi trường Dev chung (`yas-dev`).
* **Cấu hình tham số:**
  * `PIPELINE_TARGET` = `dev_cd`
  * Cấu hình trigger: Chọn **GitHub hook trigger for GITScm polling** (để tự động chạy khi merge code vào `main`).

#### 5. Job CD môi trường Staging: `yas-staging-release`

* **Mục đích (Yêu cầu 6b):** Triển khai phiên bản phát hành dạng Tag (`v1.2.3`) lên môi trường Staging (`yas-staging`).
* **Cấu hình tham số:**
  * `PIPELINE_TARGET` = `staging_release`
  * Cấu hình trigger: Chọn lắng nghe sự kiện push tag từ GitHub.

---

## GIAI ĐOẠN 4: THỰC HIỆN KIỂM TRA THỰC TẾ (TEST FLOW)

Sau khi thiết lập xong Jenkins và môi trường, chạy thử nghiệm theo đúng thứ tự sau:

### Bước 1: Chạy thử Job CI (`yas-ci`)

1. Tạo một nhánh mới dưới local: `git checkout -b test_branch`.
2. Sửa một dòng code nhỏ trong service `product` rồi commit và push nhánh này lên GitHub.
3. Vào Jenkins, chạy Job `yas-ci`. Điền parameter nhánh là `test_branch`.
4. **Xác nhận thành công:** Kiểm tra Docker Hub cá nhân của bạn xem đã xuất hiện image `product` với tag là mã Commit SHA của bạn chưa.

### Bước 2: Chạy thử Job Deploy Thử Nghiệm (`yas-developer-build`)

1. Vào Jenkins chọn Job `yas-developer-build`.
2. Tại ô tham số của `product_BRANCH`, điền: `test_branch` (nhánh cá nhân). Các ô khác giữ nguyên `main`. Bấm **Build**.
3. Sau khi build thành công, Jenkins sẽ deploy 14 services vào namespace `yas-user-test-branch` trên K8s.
4. Mở file `C:\Windows\System32\drivers\etc\hosts` trên máy tính với quyền Administrator, thêm dòng sau:
   ```text
   127.0.0.1   storefront.yas.local
   127.0.0.1   backoffice.yas.local
   ```
5. Truy cập thử `http://storefront.yas.local:32080` từ trình duyệt để kiểm thử giao diện cửa hàng liên kết với service `product` chạy code thử nghiệm của bạn.

### Bước 3: Dọn dẹp (`yas-developer-cleanup`)

1. Vào Jenkins chạy job `yas-developer-cleanup`.
2. Điền vào ô `DEVELOPER_ID` giá trị: `test-branch`. Bấm **Build**.
3. **Xác nhận thành công:** Kiểm tra terminal dưới máy local chạy lệnh `kubectl get ns`, namespace `yas-user-test-branch` phải biến mất.

### Bước 4: Chạy CD Dev chung (`yas-dev-cd`)

1. Thực hiện Merge nhánh `test_branch` vào nhánh `main` trên GitHub.
2. Kiểm tra Jenkins xem Job `yas-dev-cd` có tự động chạy hay không.
3. **Xác nhận thành công:** Gõ lệnh `kubectl get pods -n yas-dev`. Các pod thuộc namespace `yas-dev` sẽ tự động khởi tạo lại với code mới nhất.

### Bước 5: Chạy CD Staging (`yas-staging-release`)

1. Đánh tag phát hành trên Git và push lên GitHub:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. Kiểm tra Jenkins xem Job `yas-staging-release` có chạy hay không.
3. **Xác nhận thành công:** Gõ lệnh `kubectl get pods -n yas-staging`. Toàn bộ các dịch vụ sẽ được chạy với Image tag cố định là `v1.0.0`.
