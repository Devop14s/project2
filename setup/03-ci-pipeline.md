# Yêu cầu 3: CI Pipeline — Build và Push image theo commit ID

## Tóm tắt yêu cầu

- Với **mỗi branch** do user tạo, sau khi có commit mới:
  1. Build image cho service tương ứng.
  2. Tag image bằng **commit SHA ngắn** (7 ký tự) của commit cuối cùng trên branch đó.
  3. Push image lên Docker Hub.

---

## Luồng CI

```
Developer push code lên branch
        ↓
GitHub webhook kích hoạt Jenkins
        ↓
Jenkins checkout branch
        ↓
Resolve GIT_COMMIT (lấy SHA 7 ký tự)
        ↓
Build Docker image(s)
        ↓
Push lên Docker Hub với tag = <short-sha>
        ↓
Lưu metadata (commit sha, image list)
```

---

## Cấu hình Jenkins — Multibranch Pipeline

### Bước 1: Tạo Multibranch Pipeline job

1. Jenkins → New Item → **Multibranch Pipeline**
2. Đặt tên: `yas-ci`
3. Branch Sources → **GitHub**:
   - Repository URL: `https://github.com/<your-fork>/yas`
   - Credentials: GitHub token (tạo ở bước tiếp)
4. Build Configuration → **by Jenkinsfile** → Script Path: `Jenkinsfile` (hoặc `ci/Jenkinsfile`)
5. Scan Multibranch Pipeline Triggers: **Periodically if not otherwise run** → 1 minute (hoặc dùng webhook)

### Bước 2: Tạo GitHub Personal Access Token

1. GitHub → Settings → Developer settings → Personal access tokens → **Generate new token**
2. Scopes: `repo`, `read:org`
3. Thêm vào Jenkins:
   - Kind: **Username with password**
   - ID: `github-credentials`
   - Username: GitHub username
   - Password: token vừa tạo

### Bước 3: Cấu hình GitHub Webhook (tùy chọn, nhanh hơn polling)

1. GitHub repo → Settings → Webhooks → **Add webhook**
2. Payload URL: `http://<jenkins-url>/github-webhook/`
3. Content type: `application/json`
4. Events: **Just the push event**

---

## Jenkinsfile — CI Pipeline

```groovy
pipeline {
    agent any

    environment {
        DOCKERHUB_NS   = '<your-dockerhub-username>'
        DOCKER_CREDS   = 'dockerhub-credentials'   // Jenkins credential ID
        GITHUB_CREDS   = 'github-credentials'
        YAS_REPO       = 'https://github.com/<your-fork>/yas.git'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${BRANCH_NAME}"]],
                    userRemoteConfigs: [[
                        url: env.YAS_REPO,
                        credentialsId: env.GITHUB_CREDS
                    ]]
                ])
            }
        }

        stage('Resolve Commit') {
            steps {
                script {
                    env.SHORT_SHA = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true
                    ).trim()
                    echo "Branch: ${BRANCH_NAME} | Commit: ${SHORT_SHA}"
                }
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDS,
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
                }
            }
        }

        stage('Build & Push Images') {
            steps {
                script {
                    // Danh sách service cần build
                    // 13 services active (sampledata seed riêng, không CI thường xuyên)
                    def services = [
                        'product', 'cart', 'order', 'customer', 'inventory',
                        'tax', 'media', 'search',
                        'storefront-bff', 'storefront',
                        'backoffice-bff', 'backoffice',
                        'swagger-ui'
                    ]

                    services.each { svc ->
                        def imgName = "${DOCKERHUB_NS}/yas-${svc}"
                        def tag     = env.SHORT_SHA

                        sh """
                            docker build -t ${imgName}:${tag} ./${svc}/
                            docker push ${imgName}:${tag}
                            echo "${imgName}:${tag}" >> work/built-image-list.txt
                        """
                    }
                }
            }
        }

        stage('Save Metadata') {
            steps {
                sh """
                    mkdir -p work
                    echo "${SHORT_SHA}" > work/commit_short_sha.txt
                    git rev-parse HEAD  > work/commit_sha.txt
                    echo "Branch: ${BRANCH_NAME}, SHA: ${SHORT_SHA}" >> work/build-summary.txt
                """
                archiveArtifacts artifacts: 'work/**', allowEmptyArchive: true
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo "CI thành công. Images tagged: ${SHORT_SHA}"
        }
        failure {
            echo "CI thất bại. Kiểm tra log bên trên."
        }
    }
}
```

---

## Xử lý build chọn lọc theo service

Nếu không muốn build tất cả service mỗi lần push (tốn thời gian), có thể detect service thay đổi:

```groovy
stage('Detect Changed Services') {
    steps {
        script {
            def changed = sh(
                script: 'git diff --name-only HEAD~1 HEAD',
                returnStdout: true
            ).trim().split('\n')

            env.CHANGED_SERVICES = changed
                .collect { it.split('/')[0] }        // lấy tên thư mục gốc
                .findAll { it in ALL_SERVICES }       // lọc chỉ service hợp lệ
                .unique()
                .join(',')

            echo "Services thay đổi: ${env.CHANGED_SERVICES}"
        }
    }
}
```

> **Lưu ý**: Để đơn giản, có thể build **tất cả service** mỗi lần push và chỉ push image của service thay đổi. Nhưng trong đồ án, build tất cả là acceptable.

---

## Ví dụ kết quả sau CI

Developer push lên branch `dev_tax_service`, commit SHA = `a1b2c3d`:

```
Docker Hub:
  myname/yas-tax:a1b2c3d          ← built từ branch dev_tax_service
  myname/yas-product:a1b2c3d      ← cũng build (nếu build all)
  ...

work/commit_short_sha.txt:
  a1b2c3d

work/built-image-list.txt:
  myname/yas-tax:a1b2c3d
  myname/yas-product:a1b2c3d
  ...
```

---

## Checklist xác nhận

- [ ] Multibranch Pipeline job `yas-ci` đã tạo
- [ ] Jenkins credential `github-credentials` đã cấu hình
- [ ] Jenkins credential `dockerhub-credentials` đã cấu hình
- [ ] Webhook hoặc polling đã cấu hình để trigger khi có push
- [ ] Tạo branch test, push 1 commit → pipeline chạy tự động
- [ ] Image với tag `<short-sha>` xuất hiện trên Docker Hub
- [ ] File `work/commit_short_sha.txt` được archive
