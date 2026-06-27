# Yêu cầu 4: Jenkins Job CD — `developer_build`

## Tóm tắt yêu cầu

Tạo Jenkins job tên **`developer_build`** cho phép developer:
1. Chọn branch cho từng service muốn test.
2. Deploy toàn bộ hệ thống lên K8S: service đang test dùng image từ branch đó (tag = commit SHA), các service còn lại dùng tag `main`.
3. Nhận về `domain:port` (dạng NodePort) để truy cập và test.

## File triển khai thực tế trong repo

Job `developer_build` đã có scaffold sẵn tại:

- `jenkins/pipelines/developer_build.groovy`
- `jenkins/scripts/resolve-branch-tags.sh`
- `jenkins/scripts/deploy-helm.sh`
- `jenkins/scripts/capture-runtime-evidence.sh`
- `jenkins/scripts/smoke-test.sh`

## Cấu hình thực tế đang dùng

Pipeline thực tế hiện tại dùng:

- Docker credential ID: `dockerhub-creds`
- Kubernetes credential ID: `kubeconfig-file`
- Parameter quan trọng:
  - `DEPLOYER_ID`
  - `SERVICE_CATALOG`
  - `DOCKERHUB_NAMESPACE`
  - `DOMAIN_NAME`
  - `BACKOFFICE_DOMAIN_NAME`
  - `STOREFRONT_BRANCH`
  - `BACKOFFICE_BRANCH`
  - `STOREFRONT_BFF_BRANCH`
  - `BACKOFFICE_BFF_BRANCH`
  - `PRODUCT_BRANCH`
  - `CART_BRANCH`
  - `CUSTOMER_BRANCH`
  - `ORDER_BRANCH`
  - `INVENTORY_BRANCH`
  - `TAX_BRANCH`
  - ...

> Khi chạy thật, ưu tiên parameter theo `jenkins/pipelines/developer_build.groovy`.

---

## Luồng hoạt động

```
Developer mở job developer_build
         ↓
Chọn parameter branch override cho service cần test
                (các service khác = main)
         ↓
Jenkins resolve tag:
  - service được override: đọc commit SHA mới nhất của branch đó
  - các service khác: dùng tag "main"
         ↓
Jenkins deploy lên namespace yas-user-<deployer-id> bằng Helm
         ↓
Jenkins in ra: yas.local:30080 (NodePort URL)
         ↓
Developer thêm vào /etc/hosts: <WORKER_IP> yas.local
         ↓
Developer truy cập http://yas.local:30080 để test
```

---

## Tạo Job trên Jenkins

### Bước 1: New Item

1. Jenkins → **New Item**
2. Tên: `developer_build`
3. Loại: **Pipeline**
4. OK

### Bước 2: Cấu hình Parameters

Vào **This project is parameterized** → thêm các String Parameter:

| Parameter name | Default value | Mô tả |
|---|---|---|
| `DEPLOYER_ID` | `dev1` | ID định danh của developer (dùng đặt namespace) |
| `SERVICE_CATALOG` | `release-baseline` | Catalog deploy lần đầu |
| `DOCKERHUB_NAMESPACE` | `<namespace>` | Docker namespace |
| `DOMAIN_NAME` | `storefront-dev1.yas.local` | Domain storefront |
| `BACKOFFICE_DOMAIN_NAME` | `backoffice-dev1.yas.local` | Domain backoffice |
| `STOREFRONT_BRANCH` | `main` | Branch của storefront |
| `BACKOFFICE_BRANCH` | `main` | Branch của backoffice |
| `STOREFRONT_BFF_BRANCH` | `main` | Branch của storefront-bff |
| `BACKOFFICE_BFF_BRANCH` | `main` | Branch của backoffice-bff |
| `PRODUCT_BRANCH` | `main` | Branch của product |
| `CART_BRANCH` | `main` | Branch của cart |
| `CUSTOMER_BRANCH` | `main` | Branch của customer |
| `ORDER_BRANCH` | `main` | Branch của order |
| `INVENTORY_BRANCH` | `main` | Branch của inventory |
| `TAX_BRANCH` | `main` | Branch của tax |

> Tất cả default = `main`. Developer chỉ thay đổi service mình đang làm việc.

---

## Việc có thể làm ngay lúc chờ Jenkins

- Chốt `DEPLOYER_ID` dùng khi demo
- Chốt `DOMAIN_NAME` và `BACKOFFICE_DOMAIN_NAME`
- Chuẩn bị branch override nào sẽ test đầu tiên
- Ghi sẵn lệnh kiểm tra sau deploy:
  - `kubectl get pods -n yas-user-<deployer-id>`
  - `kubectl get svc -n yas-user-<deployer-id>`

---

## Jenkinsfile — developer_build

> Khối ví dụ dưới đây là mô tả luồng cũ. Khi chạy Jenkins thật, ưu tiên parameter và stage theo `jenkins/pipelines/developer_build.groovy`.

```groovy
pipeline {
    agent any

    parameters {
        string(name: 'DEPLOYER_ID',          defaultValue: 'dev1', description: 'ID của developer')
        string(name: 'BRANCH_PRODUCT',       defaultValue: 'main', description: 'Branch product-service')
        string(name: 'BRANCH_CART',          defaultValue: 'main', description: 'Branch cart-service')
        string(name: 'BRANCH_ORDER',         defaultValue: 'main', description: 'Branch order-service')
        string(name: 'BRANCH_CUSTOMER',      defaultValue: 'main', description: 'Branch customer-service')
        string(name: 'BRANCH_INVENTORY',     defaultValue: 'main', description: 'Branch inventory-service')
        string(name: 'BRANCH_TAX',           defaultValue: 'main', description: 'Branch tax-service')
        string(name: 'BRANCH_MEDIA',         defaultValue: 'main', description: 'Branch media-service')
        string(name: 'BRANCH_SEARCH',        defaultValue: 'main', description: 'Branch search-service')
        string(name: 'BRANCH_STOREFRONT_BFF',defaultValue: 'main', description: 'Branch storefront-bff')
        string(name: 'BRANCH_STOREFRONT_UI', defaultValue: 'main', description: 'Branch storefront-ui')
        string(name: 'BRANCH_BACKOFFICE_BFF',defaultValue: 'main', description: 'Branch backoffice-bff')
        string(name: 'BRANCH_BACKOFFICE_UI', defaultValue: 'main', description: 'Branch backoffice-ui')
        string(name: 'BRANCH_SWAGGER',       defaultValue: 'main', description: 'Branch swagger-ui')
    }

    environment {
        DOCKERHUB_NS  = '<your-dockerhub-username>'
        NAMESPACE     = "yas-user-${params.DEPLOYER_ID}"
        YAS_REPO      = 'https://github.com/<your-fork>/yas.git'
        GITHUB_CREDS  = 'github-credentials'
        WORKER_IP     = '<worker-node-ip>'   // IP của K8S worker node
    }

    stages {
        stage('Prepare Namespace') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
                    sh """
                        export KUBECONFIG=\$KUBECONFIG
                        kubectl get namespace ${NAMESPACE} || kubectl create namespace ${NAMESPACE}
                    """
                }
            }
        }

        stage('Resolve Image Tags') {
            steps {
                script {
                    // Map service → branch
                    def branchMap = [
                        'product'       : params.BRANCH_PRODUCT,
                        'cart'          : params.BRANCH_CART,
                        'order'         : params.BRANCH_ORDER,
                        'customer'      : params.BRANCH_CUSTOMER,
                        'inventory'     : params.BRANCH_INVENTORY,
                        'tax'           : params.BRANCH_TAX,
                        'media'         : params.BRANCH_MEDIA,
                        'search'        : params.BRANCH_SEARCH,
                        'storefront-bff': params.BRANCH_STOREFRONT_BFF,
                        'storefront'    : params.BRANCH_STOREFRONT_UI,
                        'backoffice-bff': params.BRANCH_BACKOFFICE_BFF,
                        'backoffice'    : params.BRANCH_BACKOFFICE_UI,
                        'swagger-ui'    : params.BRANCH_SWAGGER,
                    ]

                    // Resolve tag: nếu branch != main thì lấy commit SHA của branch đó
                    env.HELM_SET_ARGS = branchMap.collect { svc, branch ->
                        if (branch == 'main') {
                            "--set services.${svc}.tag=main"
                        } else {
                            // Clone YAS repo và lấy commit SHA của branch
                            def sha = sh(
                                script: """
                                    git ls-remote ${YAS_REPO} refs/heads/${branch} | cut -c1-7
                                """,
                                returnStdout: true
                            ).trim()
                            echo "Service ${svc}: branch=${branch} → tag=${sha}"
                            "--set services.${svc}.tag=${sha}"
                        }
                    }.join(' ')
                }
            }
        }

        stage('Deploy via Helm') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
                    sh """
                        export KUBECONFIG=\$KUBECONFIG
                        helm upgrade --install yas-dev-${params.DEPLOYER_ID} ./helm/yas \
                            --namespace ${NAMESPACE} \
                            --set global.imageRegistry=${DOCKERHUB_NS} \
                            --set global.serviceType=NodePort \
                            ${env.HELM_SET_ARGS} \
                            --wait --timeout 5m
                    """
                }
            }
        }

        stage('Get NodePort & Print Access Info') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
                    script {
                        def port = sh(
                            script: """
                                export KUBECONFIG=\$KUBECONFIG
                                kubectl get svc -n ${NAMESPACE} yas-storefront-svc \
                                    -o jsonpath='{.spec.ports[0].nodePort}'
                            """,
                            returnStdout: true
                        ).trim()

                        echo """
==========================================================
  DEPLOY THÀNH CÔNG
==========================================================
  Namespace : ${NAMESPACE}
  Worker IP : ${WORKER_IP}
  NodePort  : ${port}

  Truy cập  : http://yas.local:${port}

  Thêm vào /etc/hosts (trên máy developer):
    ${WORKER_IP}  yas.local

  Lệnh test nhanh:
    curl -I http://${WORKER_IP}:${port}
==========================================================
                        """
                    }
                }
            }
        }
    }

    post {
        failure {
            echo "Deploy thất bại. Kiểm tra log phía trên để debug."
        }
    }
}
```

---

## Ví dụ sử dụng

**Scenario**: Developer đang làm việc ở branch `dev_tax_service`.

1. Mở Jenkins → job `developer_build` → **Build with Parameters**
2. Nhập:
   ```
   DEPLOYER_ID     : dev1
   BRANCH_TAX      : dev_tax_service    ← thay đổi duy nhất
   BRANCH_PRODUCT  : main
   BRANCH_CART     : main
   ... (còn lại để default)
   ```
3. Click **Build**
4. Jenkins sẽ:
   - Lấy commit SHA mới nhất của `dev_tax_service` (ví dụ `a1b2c3d`)
   - Deploy với `yas-tax:a1b2c3d`, còn lại dùng `:main`
   - In ra access URL ở cuối log

**Output log cuối job:**
```
==========================================================
  DEPLOY THÀNH CÔNG
==========================================================
  Namespace : yas-user-dev1
  Worker IP : 192.168.1.100
  NodePort  : 31234

  Truy cập  : http://yas.local:31234

  Thêm vào /etc/hosts (trên máy developer):
    192.168.1.100  yas.local
==========================================================
```

5. Developer thêm vào `/etc/hosts`:
   ```
   192.168.1.100  yas.local
   ```
6. Mở trình duyệt: `http://yas.local:31234`

---

## Cấu hình Helm Chart cho NodePort

Trong `helm/yas/templates/storefront-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: yas-storefront-svc
spec:
  type: {{ .Values.global.serviceType | default "ClusterIP" }}
  selector:
    app: yas-storefront
  ports:
    - port: 80
      targetPort: 3000
      nodePort: {{ .Values.storefront.nodePort | default 30080 }}
```

Trong `helm/yas/values.yaml`:

```yaml
global:
  serviceType: NodePort

storefront:
  nodePort: 30080

backoffice:
  nodePort: 30081
```

---

## Checklist xác nhận

- [ ] Job `developer_build` đã tạo trên Jenkins
- [ ] Tất cả parameters đã cấu hình với default = `main`
- [ ] Jenkinsfile đặt đúng path trong job config
- [ ] Helm chart hỗ trợ `serviceType=NodePort`
- [ ] Test scenario: chỉ thay 1 branch, deploy thành công
- [ ] Log cuối job hiển thị `NodePort` và hướng dẫn `/etc/hosts`
- [ ] Developer có thể truy cập `http://yas.local:<port>` từ máy của họ
