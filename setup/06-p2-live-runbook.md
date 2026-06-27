# P2 Live Runbook

## Mục tiêu

Hoàn thiện phần runtime của P2 theo đúng thứ tự sau:

1. Hoàn tất cluster `k3s` 2 node
2. Dựng Jenkins trên local master, kết nối với cluster
3. Chạy CI/CD flow thật
4. Thu đủ evidence để nộp bài

---

## Trạng thái hiện tại (cập nhật 27/06/2026)

Đã xong:

- `k3s` master chạy trên WSL2 (192.168.11.26) — máy hiện tại đang dùng
- `k3s` worker đã join thành công (192.168.11.223)
- `kubectl get nodes` trả về cả 2 node đều `Ready`
- Namespace `yas-dev` và `yas-staging` đã tạo
- Credential `kubeconfig-file` đã upload lên Jenkins (cần xác nhận lại sau khi fix server address)

Đang chờ / chưa hoàn thành:

- Dựng Jenkins trên local master thay thế Jenkins cũ ở `20.2.66.240`
- Cài `helm` trên master
- Fix kubeconfig server address (`0.0.0.0` → `127.0.0.1` nếu Jenkins chạy local, hoặc `192.168.11.26` nếu client/Jenkins chạy từ máy khác)
- Chạy CI/CD end-to-end từ Jenkins local

---

## Chuẩn bị môi trường trên master (làm 1 lần)

### Bước A: Cài helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version --short
```

### Bước B: Fix kubectl context

K3s cài kubectl riêng tại `/usr/local/bin/k3s`. Tạo wrapper để dùng như `kubectl` bình thường:

```bash
# Kiểm tra k3s kubectl có hoạt động không
sudo k3s kubectl get nodes

# Nếu muốn dùng kubectl không cần sudo, dùng kubeconfig user
export KUBECONFIG=~/.kube/config
kubectl get nodes
```

### Bước C: Fix kubeconfig server address

Jenkins chạy trong Docker container nên phải dùng IP thật của master (không phải `127.0.0.1` vì container không resolve được localhost của host):

```bash
sed -i 's|https://0.0.0.0:6443|https://192.168.11.26:6443|g' ~/.kube/config
grep "server:" ~/.kube/config
# Kỳ vọng: server: https://192.168.11.26:6443
kubectl get nodes
```

✅ **Đã thực hiện** — kubeconfig hiện trỏ đúng `https://192.168.11.26:6443`.

Sau bước này, upload `~/.kube/config` lên Jenkins credential `kubeconfig-file`.

---

## Bước 1: Dựng Jenkins trên local master

### Lựa chọn A — Chạy Jenkins bằng Docker (khuyến nghị)

```bash
docker run -d \
  --name jenkins \
  --restart=unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.kube:/root/.kube:ro \
  jenkins/jenkins:lts
```

Lấy initial admin password:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Mở: `http://127.0.0.1:8080` (hoặc `http://192.168.11.26:8080` từ máy khác trong LAN).

Cài thêm `kubectl` và `helm` vào trong container:

```bash
docker exec -u root jenkins bash -c "
  apt-get update && apt-get install -y apt-transport-https gnupg &&
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg &&
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' > /etc/apt/sources.list.d/kubernetes.list &&
  apt-get update && apt-get install -y kubectl &&
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
"
```

Kiểm tra từ bên trong container:

```bash
docker exec jenkins kubectl version --client
docker exec jenkins helm version --short
```

### Lựa chọn B — Chạy Jenkins bằng systemd (nếu không dùng Docker container)

```bash
# Cài Java 17/21 (đã có Java 21)
# Tải jenkins.war
wget -q -O /tmp/jenkins.war https://get.jenkins.io/war-stable/latest/jenkins.war

# Chạy
java -jar /tmp/jenkins.war --httpPort=8080
```

---

## Bước 2: Cấu hình Jenkins lần đầu

### Credentials cần có

| ID | Kind | Nội dung |
|---|---|---|
| `kubeconfig-file` | Secret file | `~/.kube/config` (đã fix server address) |
| `dockerhub-creds` | Username/Password | Docker Hub login |
| `github-credentials` | Username/Password | GitHub username + token |

## Việc có thể làm ngay lúc chờ Jenkins

- Copy kubeconfig ra file tạm:

```bash
cp ~/.kube/config /tmp/kubeconfig-k3s
```

- Kiểm tra file đang trỏ đúng địa chỉ master:

```bash
grep server: ~/.kube/config
```

- Lưu output để làm evidence:

```bash
kubectl get nodes -o wide
kubectl get ns
kubectl get pods -A
```

### Tools cần cài trong Jenkins

- **Docker**: dùng Docker socket mount (Lựa chọn A) hoặc `docker` CLI trên host
- **kubectl**: cài trong container (xem Bước 1)
- **helm**: cài trong container (xem Bước 1)
- **git**: mặc định có trong Jenkins LTS

---

## Bước 3: Tạo Jenkins jobs

Tạo lần lượt theo thứ tự ưu tiên:

### Job 1: `project2-yas-ci` (Pipeline)

- Script path: `Jenkinsfile`
- Dùng file: `jenkins/pipelines/ci.groovy`

Parameters mặc định cần set:

```
DOCKERHUB_NAMESPACE = luongtrz
SOURCE_ROOT         = /var/jenkins_home/prebuilt/yas-source-upstream  (nếu có prebuilt)
SERVICE_CATALOG     = release-baseline
```

### Job 2: `developer_build` (Pipeline)

- Script path: `Jenkinsfile`
- Dùng file: `jenkins/pipelines/developer_build.groovy`

### Job 3: `developer_cleanup` (Pipeline)

- Script path: `Jenkinsfile`
- Dùng file: `jenkins/pipelines/developer_cleanup.groovy`

---

## Bước 4: Xác nhận Jenkins kết nối cluster

Tạo test pipeline nhanh:

```groovy
pipeline {
    agent any
    stages {
        stage('Test kubectl') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
                    sh 'kubectl get ns'
                    sh 'kubectl get nodes'
                }
            }
        }
        stage('Test helm') {
            steps {
                sh 'helm version --short'
            }
        }
    }
}
```

Kỳ vọng: output hiển thị `yas-dev`, `yas-staging` và cả 2 node `Ready`.

---

## Bước 5: Chạy CI thật

Pipeline dùng file: `jenkins/pipelines/ci.groovy`

Mục tiêu:

- build release baseline
- push image thật lên Docker Hub
- lưu `work/built-image-list.txt`
- lưu `work/image-digests.txt`

Evidence cần giữ:

- Jenkins console log
- danh sách image + digest

---

## Bước 6: Chạy `developer_build`

Pipeline dùng file: `jenkins/pipelines/developer_build.groovy`

Checklist:

- chọn `DEPLOYER_ID`
- override ít nhất 1 branch service
- deploy vào namespace `yas-user-<deployer-id>`
- lấy NodePort truy cập (storefront: 32080, backoffice: 32081)

Worker IP để truy cập NodePort: `192.168.11.223`

Evidence cần giữ:

- log resolve branch/tag
- log `helm upgrade --install`
- `kubectl get pods -n <namespace>`
- `curl http://192.168.11.223:32080`

---

## Bước 7: Chạy `developer_cleanup`

Pipeline dùng file: `jenkins/pipelines/developer_cleanup.groovy`

Checklist:

- giữ `DELETE_NAMESPACE=true`
- chỉ bật `ALLOW_SHARED_ENVIRONMENT_CLEANUP` / `ALLOW_SHARED_NAMESPACE_DELETE` nếu cleanup shared env
- xóa đúng release
- xác nhận namespace biến mất

Evidence cần giữ:

- log `helm uninstall`
- log `kubectl delete namespace`

---

## Bước 8: Chạy shared environment flow

Ưu tiên ít nhất 1 flow:

- `jenkins/pipelines/dev_cd.groovy`
- hoặc `jenkins/pipelines/staging_release.groovy`

Mục tiêu:

- chứng minh P2 không chỉ deploy namespace cá nhân
- có ít nhất 1 deploy dùng image/tag thật từ CI

---

## Bước 9: Thu evidence cuối cùng

Chụp hoặc lưu:

```bash
kubectl get nodes -o wide
kubectl get ns
kubectl get pods -A
kubectl get svc -A
```

Artifact nên có:

- `work/commit-metadata.json`
- `work/image-digests.txt`
- `work/runtime-evidence/<namespace>/<release>/`
- `work/cleanup-evidence/<namespace>/<release>/`

---

## Thứ tự ưu tiên nếu thời gian ngắn

1. Fix kubeconfig (`0.0.0.0` → `127.0.0.1`)
2. Dựng Jenkins bằng Docker trên master
3. Cài kubectl + helm vào Jenkins container
4. Add 3 credentials (kubeconfig-file, dockerhub-creds, github-credentials)
5. Test `kubectl get ns` từ Jenkins pipeline
6. Chạy CI job → push image
7. Chạy `developer_build` → lấy NodePort evidence
8. Chạy `developer_cleanup` → evidence xóa namespace

---

## Mốc hoàn thành P2

P2 được xem là hoàn thiện thực chiến khi có đủ:

- cluster `master + worker` (✅ xong)
- Jenkins CI push image thật
- Jenkins `developer_build` deploy thật
- Jenkins `developer_cleanup` xóa thật
- ít nhất 1 shared-environment deploy flow
- evidence đầy đủ cho báo cáo
