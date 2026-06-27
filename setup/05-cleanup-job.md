# Yêu cầu 5: Jenkins Job — Xóa Deployment của `developer_build`

## Tóm tắt yêu cầu

Tạo Jenkins job để **xóa** (teardown) môi trường đã deploy bởi job `developer_build` ở yêu cầu 4.

## File triển khai thực tế trong repo

Job cleanup đã có scaffold sẵn tại:

- `jenkins/pipelines/developer_cleanup.groovy`
- `jenkins/scripts/cleanup-release.sh`

## Cấu hình thực tế đang dùng

Pipeline cleanup thực tế hiện tại dùng:

- `DEPLOYER_ID`
- `SERVICE_CATALOG`
- `NAMESPACE`
- `RELEASE_NAME`
- `DELETE_NAMESPACE`
- `ALLOW_SHARED_ENVIRONMENT_CLEANUP`
- `ALLOW_SHARED_NAMESPACE_DELETE`

> Pipeline hiện tại không còn dùng `CONFIRM_DELETE=true/false` như ví dụ cũ bên dưới. Khi chạy thật, ưu tiên theo `jenkins/pipelines/developer_cleanup.groovy`.

---

## Lý do cần job cleanup riêng

- Sau khi developer test xong, cần giải phóng tài nguyên K8S.
- Không nên để developer tự xóa thủ công trên cluster (rủi ro xóa nhầm namespace khác).
- Job cleanup cung cấp một nơi kiểm soát, có log, có thể audit.

---

## Tạo Job trên Jenkins

### Bước 1: New Item

1. Jenkins → **New Item**
2. Tên: `developer_cleanup`
3. Loại: **Pipeline**
4. OK

### Bước 2: Cấu hình Parameters

| Parameter name | Default | Mô tả |
|---|---|---|
| `DEPLOYER_ID` | `dev1` | ID của developer muốn cleanup |
| `SERVICE_CATALOG` | `release-baseline` | Catalog liên quan tới release cần xóa |
| `NAMESPACE` | *(trống)* | Override namespace nếu cần |
| `RELEASE_NAME` | *(trống)* | Override release name nếu cần |
| `DELETE_NAMESPACE` | `true` | Xóa namespace sau khi uninstall |
| `ALLOW_SHARED_ENVIRONMENT_CLEANUP` | `false` | Chỉ bật nếu cleanup shared env |
| `ALLOW_SHARED_NAMESPACE_DELETE` | `false` | Chỉ bật nếu xóa namespace shared env |

> Safety net hiện tại là `ALLOW_SHARED_ENVIRONMENT_CLEANUP` và `ALLOW_SHARED_NAMESPACE_DELETE`.

---

## Việc có thể làm ngay lúc chờ Jenkins

- Chốt naming cho `DEPLOYER_ID`
- Ghi sẵn namespace/release sẽ cleanup khi demo
- Quy ước rõ khi nào được cleanup shared environment

---

## Jenkinsfile — developer_cleanup

> Khối ví dụ dưới đây là tham khảo cũ. Khi chạy Jenkins thật, ưu tiên parameter và logic trong `jenkins/pipelines/developer_cleanup.groovy`.

```groovy
pipeline {
    agent any

    parameters {
        string(name: 'DEPLOYER_ID',    defaultValue: 'dev1',  description: 'ID của developer cần cleanup')
        booleanParam(name: 'CONFIRM_DELETE', defaultValue: false, description: 'Đặt true để xác nhận xóa')
    }

    environment {
        NAMESPACE    = "yas-user-${params.DEPLOYER_ID}"
        RELEASE_NAME = "yas-dev-${params.DEPLOYER_ID}"
    }

    stages {
        stage('Safety Check') {
            steps {
                script {
                    if (!params.CONFIRM_DELETE) {
                        error("""
==========================================================
  ABORTED: CONFIRM_DELETE = false
  
  Đặt CONFIRM_DELETE = true để xác nhận xóa namespace:
    ${NAMESPACE}
    
  Nếu không chắc, ĐỪNG bật tham số này.
==========================================================
                        """)
                    }
                    echo "Xác nhận xóa: namespace=${NAMESPACE}, release=${RELEASE_NAME}"
                }
            }
        }

        stage('Helm Uninstall') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
                    sh """
                        export KUBECONFIG=\$KUBECONFIG
                        
                        # Kiểm tra release có tồn tại không
                        if helm status ${RELEASE_NAME} -n ${NAMESPACE} > /dev/null 2>&1; then
                            echo "Đang xóa Helm release: ${RELEASE_NAME}"
                            helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}
                        else
                            echo "Release ${RELEASE_NAME} không tồn tại hoặc đã xóa rồi."
                        fi
                    """
                }
            }
        }

        stage('Delete Namespace') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
                    sh """
                        export KUBECONFIG=\$KUBECONFIG
                        
                        if kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
                            echo "Đang xóa namespace: ${NAMESPACE}"
                            kubectl delete namespace ${NAMESPACE} --timeout=60s
                            echo "Namespace ${NAMESPACE} đã xóa."
                        else
                            echo "Namespace ${NAMESPACE} không tồn tại."
                        fi
                    """
                }
            }
        }

        stage('Verify Cleanup') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
                    sh """
                        export KUBECONFIG=\$KUBECONFIG
                        
                        echo "=== Kiểm tra sau cleanup ==="
                        kubectl get namespace ${NAMESPACE} 2>&1 || echo "OK: Namespace đã không còn tồn tại."
                        
                        echo "=== Danh sách namespace còn lại ==="
                        kubectl get namespaces | grep yas
                    """
                }
            }
        }
    }

    post {
        success {
            echo """
==========================================================
  CLEANUP THÀNH CÔNG
  
  Đã xóa:
    - Helm release : ${RELEASE_NAME}
    - Namespace    : ${NAMESPACE}
==========================================================
            """
        }
        failure {
            echo "Cleanup thất bại. Kiểm tra log và xóa thủ công nếu cần."
        }
    }
}
```

---

## Luồng sử dụng sau khi test xong

```
Developer test xong feature
         ↓
Mở Jenkins → job developer_cleanup
         ↓
Nhập DEPLOYER_ID = dev1 (hoặc ID của mình)
Giữ `DELETE_NAMESPACE=true`
và chỉ bật `ALLOW_SHARED_ENVIRONMENT_CLEANUP` / `ALLOW_SHARED_NAMESPACE_DELETE`
nếu đang cleanup shared environment
         ↓
Click Build
         ↓
Jenkins:
  1. Helm uninstall release yas-dev-dev1
  2. kubectl delete namespace yas-user-dev1
  3. Xác nhận namespace đã xóa
         ↓
Tài nguyên K8S được giải phóng
```

---

## Thêm link cleanup vào log của `developer_build` (tham khảo)

Theo yêu cầu, tham khảo thêm hyperlink vào Jenkins job log:

```groovy
// Ở cuối stage 'Get NodePort' trong developer_build Jenkinsfile
echo """
  Khi test xong, chạy cleanup tại:
  ${JENKINS_URL}job/developer_cleanup/build?delay=0sec
  
  Hoặc dùng Jenkins Job Builder để tạo link trực tiếp trong build description.
"""
```

Sử dụng **Jenkins Description Setter Plugin** để gắn link HTML vào build description:

```groovy
// Cài plugin: "Description Setter Plugin"
stage('Set Build Description') {
    steps {
        script {
            currentBuild.description = """
                <b>Deploy:</b> namespace=${NAMESPACE}<br/>
                <b>URL:</b> <a href="http://${WORKER_IP}:${PORT}">http://yas.local:${PORT}</a><br/>
                <b>Cleanup:</b> <a href="${JENKINS_URL}job/developer_cleanup">Chạy cleanup job</a>
            """
        }
    }
}
```

---

## Tùy chọn nâng cao: Tự động cleanup sau N giờ

Nếu muốn tự động cleanup sau khi deploy một thời gian:

```groovy
// Thêm vào cuối developer_build
stage('Schedule Auto Cleanup') {
    steps {
        build job: 'developer_cleanup',
              parameters: [
                  string(name: 'DEPLOYER_ID', value: params.DEPLOYER_ID),
                  booleanParam(name: 'DELETE_NAMESPACE', value: true)
              ],
              wait: false,
              quietPeriod: 14400   // 4 tiếng = 14400 giây
    }
}
```

---

## Checklist xác nhận

- [ ] Job `developer_cleanup` đã tạo trên Jenkins
- [ ] Tham số `DEPLOYER_ID`, `DELETE_NAMESPACE`, `ALLOW_SHARED_ENVIRONMENT_CLEANUP`, `ALLOW_SHARED_NAMESPACE_DELETE` đã cấu hình
- [ ] Test: deploy với `developer_build`, sau đó chạy `developer_cleanup` → namespace bị xóa
- [ ] Verify: `kubectl get ns` không còn thấy `yas-user-<id>`
- [ ] Link cleanup xuất hiện trong build description của `developer_build` (optional)
