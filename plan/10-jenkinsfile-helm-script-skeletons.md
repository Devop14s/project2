# Jenkinsfile, Script Và Helm Skeletons

## 1. Mục tiêu

File này không phải code hoàn chỉnh, mà là khung nội dung nên có trong từng file để nhóm viết nhanh, ít bỏ sót.

## 2. `Jenkinsfile` skeleton

```groovy
pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
    disableConcurrentBuilds()
  }

  parameters {
    choice(name: 'PIPELINE_TARGET', choices: ['ci', 'developer_build', 'developer_cleanup', 'dev_cd', 'staging_release'], description: 'Pipeline to run')
  }

  environment {
    APP_NAME = 'yas'
    DOCKERHUB_NAMESPACE = credentials('dockerhub-namespace-text')
    DOCKERHUB_CREDS = 'dockerhub-creds'
    KUBECONFIG_CREDENTIALS = 'kubeconfig-file'
  }

  stages {
    stage('Dispatch') {
      steps {
        script {
          if (params.PIPELINE_TARGET == 'ci') {
            load 'jenkins/pipelines/ci.groovy'
          } else if (params.PIPELINE_TARGET == 'developer_build') {
            load 'jenkins/pipelines/developer_build.groovy'
          } else if (params.PIPELINE_TARGET == 'developer_cleanup') {
            load 'jenkins/pipelines/developer_cleanup.groovy'
          } else if (params.PIPELINE_TARGET == 'dev_cd') {
            load 'jenkins/pipelines/dev_cd.groovy'
          } else if (params.PIPELINE_TARGET == 'staging_release') {
            load 'jenkins/pipelines/staging_release.groovy'
          } else {
            error("Unsupported PIPELINE_TARGET=${params.PIPELINE_TARGET}")
          }
        }
      }
    }
  }
}
```

## 3. `ci.groovy` skeleton

```groovy
return {
  pipeline {
    agent any

    stages {
      stage('Checkout') {
        steps {
          checkout scm
        }
      }

      stage('Resolve Commit') {
        steps {
          sh 'git rev-parse HEAD > work/commit_sha.txt'
          sh 'git rev-parse --short HEAD > work/commit_short_sha.txt'
        }
      }

      stage('Docker Login') {
        steps {
          withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
            sh 'jenkins/scripts/docker-login.sh'
          }
        }
      }

      stage('Build Images') {
        steps {
          sh 'jenkins/scripts/build-images.sh'
        }
      }

      stage('Push Images') {
        steps {
          sh 'jenkins/scripts/push-images.sh'
        }
      }
    }
  }
}
```

## 4. `developer_build.groovy` skeleton

```groovy
return {
  pipeline {
    agent any

    parameters {
      string(name: 'DEPLOYER_ID', defaultValue: 'anv', description: 'Developer ID')
      string(name: 'tax_branch', defaultValue: 'main', description: 'Branch for tax service')
      string(name: 'product_branch', defaultValue: 'main', description: 'Branch for product service')
    }

    stages {
      stage('Checkout') {
        steps {
          checkout scm
        }
      }

      stage('Resolve Branch Tags') {
        steps {
          sh 'jenkins/scripts/resolve-branch-tags.sh'
        }
      }

      stage('Generate Values') {
        steps {
          sh 'jenkins/scripts/generate-values.sh'
        }
      }

      stage('Deploy') {
        steps {
          sh 'jenkins/scripts/deploy-helm.sh'
        }
      }

      stage('Smoke Test') {
        steps {
          sh 'jenkins/scripts/smoke-test.sh'
        }
      }
    }
  }
}
```

## 5. `developer_cleanup.groovy` skeleton

```groovy
return {
  pipeline {
    agent any

    parameters {
      string(name: 'DEPLOYER_ID', defaultValue: 'anv', description: 'Developer ID')
      string(name: 'NAMESPACE', defaultValue: '', description: 'Optional explicit namespace')
      string(name: 'RELEASE_NAME', defaultValue: '', description: 'Optional explicit release')
    }

    stages {
      stage('Checkout') {
        steps {
          checkout scm
        }
      }

      stage('Cleanup') {
        steps {
          sh 'jenkins/scripts/cleanup-release.sh'
        }
      }
    }
  }
}
```

## 6. `dev_cd.groovy` skeleton

```groovy
return {
  pipeline {
    agent any

    stages {
      stage('Checkout') {
        steps {
          checkout scm
        }
      }

      stage('Build And Push Main Images') {
        steps {
          sh 'jenkins/scripts/build-images.sh'
          sh 'jenkins/scripts/push-images.sh'
        }
      }

      stage('Deploy Dev') {
        steps {
          sh 'ENVIRONMENT=dev jenkins/scripts/generate-values.sh'
          sh 'ENVIRONMENT=dev jenkins/scripts/deploy-helm.sh'
        }
      }
    }
  }
}
```

## 7. `staging_release.groovy` skeleton

```groovy
return {
  pipeline {
    agent any

    parameters {
      string(name: 'RELEASE_VERSION', defaultValue: 'v1.0.0', description: 'Release tag')
    }

    stages {
      stage('Checkout Tag') {
        steps {
          checkout scm
        }
      }

      stage('Build And Push Release Images') {
        steps {
          sh 'RELEASE_VERSION=${RELEASE_VERSION} jenkins/scripts/build-images.sh'
          sh 'RELEASE_VERSION=${RELEASE_VERSION} jenkins/scripts/push-images.sh'
        }
      }

      stage('Deploy Staging') {
        steps {
          sh 'ENVIRONMENT=staging RELEASE_VERSION=${RELEASE_VERSION} jenkins/scripts/generate-values.sh'
          sh 'ENVIRONMENT=staging RELEASE_VERSION=${RELEASE_VERSION} jenkins/scripts/deploy-helm.sh'
        }
      }
    }
  }
}
```

## 8. `common.sh` skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing env: $name" >&2
    exit 1
  fi
}

sanitize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr -cd 'a-z0-9-'
}

image_repo() {
  local service="$1"
  echo "${DOCKERHUB_NAMESPACE}/yas-${service}"
}

release_name_for() {
  local deployer_id="$1"
  echo "yas-$(sanitize_name "$deployer_id")"
}

namespace_for() {
  local deployer_id="$1"
  echo "yas-user-$(sanitize_name "$deployer_id")"
}
```

## 9. `resolve-branch-tags.sh` skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
: > work/branch-tags.env

resolve_tag() {
  local branch="$1"
  if [[ "$branch" == "main" ]]; then
    echo "main"
    return
  fi
  git fetch origin "$branch" --depth=1
  git rev-parse "origin/$branch"
}

TAX_TAG="$(resolve_tag "${tax_branch:-main}")"
PRODUCT_TAG="$(resolve_tag "${product_branch:-main}")"

cat > work/branch-tags.env <<EOF
TAX_TAG=$TAX_TAG
PRODUCT_TAG=$PRODUCT_TAG
EOF
```

## 10. `build-images.sh` skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work
TAG="${RELEASE_VERSION:-$(git rev-parse HEAD)}"

SERVICES=(
  tax
  product
  inventory
  cart
  order
)

for service in "${SERVICES[@]}"; do
  log "Building ${service}:${TAG}"
  docker build \
    -t "$(image_repo "$service"):${TAG}" \
    -f "services/${service}/Dockerfile" \
    .
done
```

## 11. `push-images.sh` skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

TAG="${RELEASE_VERSION:-$(git rev-parse HEAD)}"

SERVICES=(
  tax
  product
  inventory
  cart
  order
)

: > work/image-list.txt

for service in "${SERVICES[@]}"; do
  image="$(image_repo "$service"):${TAG}"
  log "Pushing ${image}"
  docker push "$image"
  echo "$image" >> work/image-list.txt
done
```

## 12. `generate-values.sh` skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

mkdir -p work

ENVIRONMENT="${ENVIRONMENT:-developer}"
DEPLOYER_ID="${DEPLOYER_ID:-anv}"
NAMESPACE="${NAMESPACE:-$(namespace_for "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(release_name_for "$DEPLOYER_ID")}"

source work/branch-tags.env 2>/dev/null || true

cat > work/generated-values.yaml <<EOF
global:
  environment: ${ENVIRONMENT}
  namespace: ${NAMESPACE}

services:
  tax:
    image:
      repository: ${DOCKERHUB_NAMESPACE}/yas-tax
      tag: ${TAX_TAG:-main}
  product:
    image:
      repository: ${DOCKERHUB_NAMESPACE}/yas-product
      tag: ${PRODUCT_TAG:-main}
EOF
```

## 13. `deploy-helm.sh` skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

ENVIRONMENT="${ENVIRONMENT:-developer}"
DEPLOYER_ID="${DEPLOYER_ID:-anv}"
NAMESPACE="${NAMESPACE:-$(namespace_for "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(release_name_for "$DEPLOYER_ID")}"

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

helm upgrade --install "$RELEASE_NAME" helm/yas \
  -n "$NAMESPACE" \
  -f helm/yas/values.yaml \
  -f work/generated-values.yaml

kubectl rollout status deployment/"$RELEASE_NAME"-tax -n "$NAMESPACE" --timeout=300s
kubectl get svc -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE"
```

## 14. `cleanup-release.sh` skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail
source jenkins/scripts/common.sh

DEPLOYER_ID="${DEPLOYER_ID:-anv}"
NAMESPACE="${NAMESPACE:-$(namespace_for "$DEPLOYER_ID")}"
RELEASE_NAME="${RELEASE_NAME:-$(release_name_for "$DEPLOYER_ID")}"

helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
kubectl delete namespace "$NAMESPACE" --wait=true || true
```

## 15. `Chart.yaml` skeleton

```yaml
apiVersion: v2
name: yas
description: Helm chart for Yet Another Shop
type: application
version: 0.1.0
appVersion: "1.0.0"
```

## 16. `values.yaml` skeleton

```yaml
global:
  environment: default
  domainBase: yas.local

services:
  tax:
    enabled: true
    image:
      repository: docker.io/org/yas-tax
      tag: main
      pullPolicy: IfNotPresent
    containerPort: 8080
    service:
      type: ClusterIP
      port: 8080

  product:
    enabled: true
    image:
      repository: docker.io/org/yas-product
      tag: main
      pullPolicy: IfNotPresent
    containerPort: 8080
    service:
      type: ClusterIP
      port: 8080

entrypoints:
  storefront:
    service:
      type: NodePort
      port: 80
      nodePort: 32080
```

## 17. `templates/_helpers.tpl` skeleton

```tpl
{{- define "yas.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "yas.serviceName" -}}
{{- printf "%s-%s" .Release.Name .serviceName | trunc 63 | trimSuffix "-" -}}
{{- end -}}
```

## 18. `templates/deployment.yaml` skeleton

```yaml
{{- range $name, $svc := .Values.services }}
{{- if $svc.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $.Release.Name }}-{{ $name }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ $.Release.Name }}-{{ $name }}
  template:
    metadata:
      labels:
        app: {{ $.Release.Name }}-{{ $name }}
    spec:
      containers:
        - name: {{ $name }}
          image: "{{ $svc.image.repository }}:{{ $svc.image.tag }}"
          imagePullPolicy: {{ $svc.image.pullPolicy }}
          ports:
            - containerPort: {{ $svc.containerPort }}
---
{{- end }}
{{- end }}
```

## 19. `templates/service.yaml` skeleton

```yaml
{{- range $name, $svc := .Values.services }}
{{- if $svc.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ $.Release.Name }}-{{ $name }}
spec:
  type: {{ $svc.service.type }}
  selector:
    app: {{ $.Release.Name }}-{{ $name }}
  ports:
    - port: {{ $svc.service.port }}
      targetPort: {{ $svc.containerPort }}
---
{{- end }}
{{- end }}
```

## 20. `values-dev.yaml` skeleton

```yaml
global:
  environment: dev

services:
  tax:
    image:
      tag: main
```

## 21. `values-staging.yaml` skeleton

```yaml
global:
  environment: staging

services:
  tax:
    image:
      tag: v1.0.0
```

## 22. `values-developer-template.yaml` skeleton

```yaml
global:
  environment: developer
  developerId: placeholder

services:
  tax:
    image:
      tag: main
```

## 23. Trình tự viết code ngắn nhất

1. Viết `Chart.yaml`, `values.yaml`, `deployment.yaml`, `service.yaml`.
2. Render chart cho 1 service.
3. Viết `common.sh`.
4. Viết `build-images.sh`, `push-images.sh`.
5. Viết `resolve-branch-tags.sh`, `generate-values.sh`, `deploy-helm.sh`.
6. Bọc từng nhóm script bằng `ci.groovy` và `developer_build.groovy`.
7. Cuối cùng mới thêm cleanup, dev, staging.

## 24. Các quyết định không nên trì hoãn

1. Tên Docker Hub namespace.
2. Tên Jenkins credentials.
3. Danh sách service thực sự cần deploy.
4. Mỗi service nằm ở path nào trong repo YAS thật.
5. Service nào sẽ được expose ra NodePort cho demo.

