# Kế hoạch triển khai ArgoCD (Nâng cao — 2đ)

## Tổng quan

Mục tiêu: dùng ArgoCD để tự động sync `dev` và `staging` thay vì Jenkins gọi `helm upgrade` trực tiếp.

Luồng sau khi hoàn thành:

```
main commit → Jenkins CI → build+push image → dev_gitops job
  → cập nhật argocd/values/dev-values.yaml → git push
  → ArgoCD phát hiện thay đổi → sync helm/yas → K8s pull image
```

Staging tương tự nhưng trigger bởi tag `v*.*.*` thay vì mỗi commit.

---

## Trạng thái hiện tại

| File | Trạng thái |
|---|---|
| `argocd/app-dev.yaml` | Có — cần apply lên cluster |
| `argocd/app-staging.yaml` | Có — cần apply lên cluster |
| `argocd/values/dev-values.yaml` | Có — image placeholder, cần update script điền đúng |
| `argocd/values/staging-values.yaml` | Có — image placeholder |
| `jenkins/pipelines/dev_gitops.groovy` | Có — cần tạo Jenkins job |
| `jenkins/pipelines/staging_gitops.groovy` | Có — cần tạo Jenkins job |
| `jenkins/scripts/update-manifest-repo.sh` | Có |
| `scripts/generate-gitops-values.sh` | Có |
| ArgoCD trên cluster | **Chưa cài** |
| Jenkins job `yas-dev-gitops` | **Chưa tạo** |
| Jenkins job `yas-staging-gitops` | **Chưa tạo** |
| Credential `github-credentials` (git push) | Cần xác nhận |

---

## Bước 1 — Cài ArgoCD lên K3s

Chạy trên master (`192.168.11.26`):

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Chờ pods Ready:

```bash
kubectl -n argocd rollout status deploy/argocd-server
kubectl get pods -n argocd
```

### Expose ArgoCD UI qua NodePort

```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30443}]}}'
```

Truy cập: `https://192.168.11.26:30443`

Lấy password ban đầu:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Login: user `admin`, password vừa lấy.

---

## Bước 2 — Fix valueFiles path trong ArgoCD Application

Hiện tại `argocd/app-dev.yaml` dùng:

```yaml
valueFiles:
  - ../../argocd/values/dev-values.yaml
```

Path `../../argocd/values/dev-values.yaml` relative từ `helm/yas/` → trỏ đúng về `argocd/values/dev-values.yaml` từ repo root. ArgoCD hỗ trợ path này từ v2.6+ nếu `server.helm.valuesFileSchemes` không bị restrict.

Nếu cluster dùng ArgoCD < v2.6, cần đổi sang cách khác. Kiểm tra version sau khi cài:

```bash
kubectl -n argocd get deploy argocd-server -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Nếu cần, dùng `extraArgs` hoặc embed trực tiếp values vào `spec.source.helm.values`. Xem Bước 2b bên dưới nếu gặp lỗi.

### Bước 2b (dự phòng) — Dùng `helm.values` inline thay vì `valueFiles`

Nếu `../../` không được chấp nhận, sửa `argocd/app-dev.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/Devop14s/project2.git
    targetRevision: main
    path: helm/yas
    helm:
      valueFiles:
        - values-dev.yaml     # file nằm trong helm/yas/, không cần ..
```

Khi đó cần copy nội dung `argocd/values/dev-values.yaml` vào `helm/yas/values-dev.yaml` và Jenkins cập nhật file đó thay vì `argocd/values/dev-values.yaml`.

---

## Bước 3 — Cho ArgoCD truy cập GitHub repo

Repo `Devop14s/project2` là public → ArgoCD có thể clone không cần credential.

Kiểm tra bằng cách apply app trước, nếu ArgoCD báo lỗi clone thì thêm repo credential:

```bash
# Dùng argocd CLI (cài riêng hoặc dùng kubectl exec)
kubectl -n argocd exec -it deploy/argocd-server -- argocd repo add \
  https://github.com/Devop14s/project2.git \
  --username <github-user> \
  --password <github-token> \
  --insecure-skip-server-verification
```

---

## Bước 4 — Apply ArgoCD Application manifests

```bash
kubectl apply -f argocd/app-dev.yaml
kubectl apply -f argocd/app-staging.yaml
```

Kiểm tra:

```bash
kubectl -n argocd get applications
# Kỳ vọng: yas-dev và yas-staging xuất hiện
```

Sau đó vào ArgoCD UI xem trạng thái sync. Lần đầu sẽ là `OutOfSync` (vì values dùng placeholder image).

Sync thử thủ công để xem có lỗi không:

```bash
kubectl -n argocd patch app yas-dev \
  -p '{"operation":{"sync":{"revision":"main"}}}' \
  --type merge
```

---

## Bước 5 — Thêm credential `github-credentials` vào Jenkins

`update-manifest-repo.sh` dùng `git push origin HEAD:<branch>`. Jenkins cần credential để push.

Trong Jenkins > Credentials > Add:
- **Kind**: Username with password
- **ID**: `github-credentials`
- **Username**: GitHub username
- **Password**: Personal Access Token (scope: `repo`)

Script `update-manifest-repo.sh` dùng `git push` trực tiếp. Cần đảm bảo remote origin được cấu hình với credentials. Thêm vào `dev_gitops.groovy` stage `Update GitOps Values`:

```groovy
stage('Update GitOps Values') {
  withCredentials([usernamePassword(
    credentialsId: 'github-credentials',
    usernameVariable: 'GIT_USER',
    passwordVariable: 'GIT_TOKEN'
  )]) {
    sh '''
      git remote set-url origin https://${GIT_USER}:${GIT_TOKEN}@github.com/Devop14s/project2.git
      export ENVIRONMENT=dev
      export VALUES_FILE=argocd/values/dev-values.yaml
      jenkins/scripts/update-manifest-repo.sh
    '''
  }
}
```

Tương tự với `staging_gitops.groovy`.

---

## Bước 6 — Tạo Jenkins jobs cho GitOps pipelines

### Job: `yas-dev-gitops`

1. Jenkins > New Item > Pipeline
2. **Tên**: `yas-dev-gitops`
3. **Pipeline script from SCM**: Git
   - Repo: `https://github.com/Devop14s/project2.git`
   - Branch: `main`
   - Script path: `Jenkinsfile`
4. **Jenkinsfile** cần gọi `dev_gitops.groovy`. Tạo hoặc sửa `Jenkinsfile` tại root:

Xem bên dưới — Bước 6b.

### Job: `yas-staging-gitops`

Tương tự, dùng `staging_gitops.groovy`.

### Bước 6b — Cập nhật Jenkinsfile để dispatch đúng pipeline

Hiện tại `Jenkinsfile` ở root có thể là generic. Mỗi job có thể dùng script inline hoặc `load()`.

Cách đơn giản nhất: mỗi job dùng **Pipeline script** (không from SCM) để load đúng file:

```groovy
// yas-dev-gitops — Pipeline script inline trong Jenkins job
def pipeline = load('jenkins/pipelines/dev_gitops.groovy')
pipeline()
```

Hoặc cấu hình `PIPELINE_DISPATCH_MODE=true` và `PIPELINE_FILE=dev_gitops.groovy` trong job environment, rồi `Jenkinsfile` dispatch theo biến đó.

---

## Bước 7 — Trigger tự động: CI → GitOps

### Dev: tự động sau mỗi commit lên `main`

Trong `ci.groovy`, sau stage `Push Images`, thêm:

```groovy
stage('Trigger Dev GitOps') {
  build job: 'yas-dev-gitops', wait: false, parameters: [
    string(name: 'DOCKERHUB_NAMESPACE', value: env.DOCKERHUB_NAMESPACE),
    string(name: 'SERVICE_CATALOG', value: env.SERVICE_CATALOG)
  ]
}
```

### Staging: trigger khi có git tag `v*.*.*`

Trong `staging_release.groovy` hoặc một job riêng detect tag:

```groovy
stage('Trigger Staging GitOps') {
  build job: 'yas-staging-gitops', wait: false, parameters: [
    string(name: 'DOCKERHUB_NAMESPACE', value: env.DOCKERHUB_NAMESPACE),
    string(name: 'RELEASE_VERSION', value: env.TAG_NAME)
  ]
}
```

Job `yas-staging-gitops` cần được cấu hình **Build Triggers** → **GitHub hook trigger** hoặc scan tags.

---

## Bước 8 — Test end-to-end

### Test 8a: Dev flow

```bash
# 1. Commit bất kỳ lên main
git commit --allow-empty -m "test: trigger argocd dev flow"
git push origin main

# 2. Jenkins CI build + push images

# 3. Jenkins yas-dev-gitops chạy → cập nhật argocd/values/dev-values.yaml

# 4. Kiểm tra commit mới trong repo:
git log argocd/values/dev-values.yaml --oneline | head -3

# 5. ArgoCD phát hiện và sync (tự động vì prune+selfHeal=true)
kubectl -n argocd get app yas-dev -w
# Kỳ vọng: Synced + Healthy

# 6. Kiểm tra pods
kubectl get pods -n yas-dev
```

### Test 8b: Staging flow

```bash
# 1. Tag trên main
git tag v1.0.0
git push origin v1.0.0

# 2. Jenkins staging_gitops chạy với RELEASE_VERSION=v1.0.0

# 3. ArgoCD sync staging (manual hoặc bật automated)
kubectl -n argocd patch app yas-staging \
  -p '{"operation":{"sync":{}}}' --type merge

# 4. Kiểm tra
kubectl get pods -n yas-staging
```

---

## Bước 9 — Thu evidence cho báo cáo

```bash
# ArgoCD applications
kubectl -n argocd get applications -o wide

# ArgoCD sync history (CLI)
kubectl -n argocd get app yas-dev -o yaml | grep -A5 "history:"

# Pods sau khi sync
kubectl get pods -n yas-dev -o wide
kubectl get pods -n yas-staging -o wide

# Screenshot ArgoCD UI: app-dev và app-staging ở trạng thái Synced + Healthy
```

---

## Checklist hoàn thành

- [ ] ArgoCD cài xong, UI truy cập được tại `https://192.168.11.26:30443`
- [ ] `argocd/app-dev.yaml` và `argocd/app-staging.yaml` apply thành công
- [ ] `yas-dev` và `yas-staging` xuất hiện trong ArgoCD UI
- [ ] Credential `github-credentials` có trong Jenkins
- [ ] Jenkins jobs `yas-dev-gitops` và `yas-staging-gitops` tạo xong
- [ ] Commit lên main → ArgoCD tự động sync `yas-dev` (automated)
- [ ] Tag `v*.*.*` → ArgoCD sync `yas-staging` (manual trigger hoặc automated)
- [ ] Evidence: screenshot ArgoCD UI + `kubectl get pods` cả 2 namespace

---

## Ghi chú kỹ thuật

### valueFiles path ArgoCD

ArgoCD v2.6+ hỗ trợ `../` trong `valueFiles`. Trước v2.6 cần dùng `helm.valuesObject` hoặc copy file vào trong chart directory.

Kiểm tra nhanh version sau khi cài:

```bash
kubectl -n argocd get deploy argocd-server -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -o 'v[0-9]*\.[0-9]*'
```

### update-manifest-repo.sh — generate-gitops-values.sh

Script `jenkins/scripts/update-manifest-repo.sh` gọi `scripts/generate-gitops-values.sh` (không phải `jenkins/scripts/`). File này tồn tại tại `scripts/generate-gitops-values.sh`. Đảm bảo Jenkins job checkout đúng repo root trước khi chạy.

### Staging automated sync

`argocd/app-staging.yaml` hiện **không** có `automated` trong `syncPolicy` (không tự sync). Đây là đúng cho staging — cần sync thủ công hoặc trigger từ Jenkins sau khi build xong.

Nếu muốn automated cho staging cũng được, thêm vào `app-staging.yaml`:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: false   # staging không tự heal, chỉ deploy khi manifest thay đổi
```
