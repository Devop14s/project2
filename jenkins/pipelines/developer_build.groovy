return {
  if (env.PIPELINE_DISPATCH_MODE != 'true') {
    properties([
      parameters([
        string(name: 'DEPLOYER_ID', defaultValue: 'dev1', description: 'Developer identifier used in namespace and hostname'),
        choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog to verify and deploy from prebuilt image tags'),
        string(name: 'DOCKERHUB_NAMESPACE', defaultValue: '', description: 'Docker registry namespace, for example docker.io/your-org'),
        string(name: 'SOURCE_ROOT', defaultValue: 'yas-source', description: 'Relative path to the YAS source tree inside this repository'),
        string(name: 'SOURCE_GIT_ROOT', defaultValue: '.', description: 'Git checkout used for branch resolution'),
        string(name: 'SOURCE_REPO_URL', defaultValue: 'https://github.com/Devop14s/yas-group14.git', description: 'Source repository URL used when the job must clone YAS on demand'),
        string(name: 'SOURCE_REPO_REF', defaultValue: 'main', description: 'Source branch, tag, or ref used when the job must clone YAS on demand'),
        string(name: 'DOMAIN_NAME', defaultValue: 'storefront-dev1.yas.local', description: 'Hostname shown to the developer'),
        string(name: 'BACKOFFICE_DOMAIN_NAME', defaultValue: 'backoffice-dev1.yas.local', description: 'Hostname shown for the backoffice UI'),
        string(name: 'STOREFRONT_BRANCH', defaultValue: 'main', description: 'Branch override for storefront'),
        string(name: 'BACKOFFICE_BRANCH', defaultValue: 'main', description: 'Branch override for backoffice'),
        string(name: 'STOREFRONT_BFF_BRANCH', defaultValue: 'main', description: 'Branch override for storefront-bff'),
        string(name: 'BACKOFFICE_BFF_BRANCH', defaultValue: 'main', description: 'Branch override for backoffice-bff'),
        string(name: 'PRODUCT_BRANCH', defaultValue: 'main', description: 'Branch override for product'),
        string(name: 'MEDIA_BRANCH', defaultValue: 'main', description: 'Branch override for media'),
        string(name: 'CART_BRANCH', defaultValue: 'main', description: 'Branch override for cart'),
        string(name: 'CUSTOMER_BRANCH', defaultValue: 'main', description: 'Branch override for customer'),
        string(name: 'RATING_BRANCH', defaultValue: 'main', description: 'Branch override for rating'),
        string(name: 'LOCATION_BRANCH', defaultValue: 'main', description: 'Branch override for location'),
        string(name: 'ORDER_BRANCH', defaultValue: 'main', description: 'Branch override for order'),
        string(name: 'INVENTORY_BRANCH', defaultValue: 'main', description: 'Branch override for inventory'),
        string(name: 'TAX_BRANCH', defaultValue: 'main', description: 'Branch override for tax'),
        string(name: 'SEARCH_BRANCH', defaultValue: 'main', description: 'Branch override for search'),
        string(name: 'PROMOTION_BRANCH', defaultValue: 'main', description: 'Branch override for promotion'),
        string(name: 'PAYMENT_BRANCH', defaultValue: 'main', description: 'Branch override for payment'),
        string(name: 'PAYMENT_PAYPAL_BRANCH', defaultValue: 'main', description: 'Branch override for payment-paypal'),
        string(name: 'RECOMMENDATION_BRANCH', defaultValue: 'main', description: 'Branch override for recommendation'),
        string(name: 'SAMPLEDATA_BRANCH', defaultValue: 'main', description: 'Branch override for sampledata'),
        string(name: 'WEBHOOK_BRANCH', defaultValue: 'main', description: 'Branch override for webhook')
      ])
    ])
  }

  node {
    stage('Checkout') {
      checkout scm
      sh 'mkdir -p work'
      def sourceBootstrap = load('jenkins/pipelines/source-bootstrap.groovy')
      env.SERVICE_CATALOG = env.SERVICE_CATALOG?.trim() ?: 'full'
      env.DOCKERHUB_NAMESPACE = env.DOCKERHUB_NAMESPACE?.trim() ?: params.DOCKERHUB_NAMESPACE?.trim()
      env.SOURCE_REPO_URL = env.SOURCE_REPO_URL?.trim() ?: params.SOURCE_REPO_URL?.trim() ?: 'https://github.com/Devop14s/yas-group14.git'
      env.SOURCE_REPO_REF = env.SOURCE_REPO_REF?.trim() ?: params.SOURCE_REPO_REF?.trim() ?: 'main'
      def sourceContext = sourceBootstrap.ensureSourceCheckout(
        sourceRootParam: env.SOURCE_ROOT?.trim() ?: params.SOURCE_ROOT?.trim() ?: 'yas-source',
        sourceGitRootParam: env.SOURCE_GIT_ROOT?.trim() ?: params.SOURCE_GIT_ROOT?.trim() ?: '.',
        sourceRepoUrl: env.SOURCE_REPO_URL,
        sourceRepoRef: env.SOURCE_REPO_REF
      )
      env.SOURCE_ROOT = sourceContext.sourceRoot
      env.SOURCE_GIT_ROOT = sourceContext.sourceGitRoot
      if (!env.DOCKERHUB_NAMESPACE) {
        error('DOCKERHUB_NAMESPACE must be provided as a parameter or Jenkins job environment value.')
      }
    }

    stage('Resolve Branch Tags') {
      sh 'jenkins/scripts/resolve-branch-tags.sh'
    }

    stage('Docker Login') {
      withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
        sh 'jenkins/scripts/docker-login.sh'
      }
    }

    stage('Verify Image Tags') {
      sh 'jenkins/scripts/verify-image-tags.sh'
    }

    stage('Generate Values') {
      sh 'jenkins/scripts/generate-values.sh'
    }

    stage('Provision Databases') {
      withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
        sh 'jenkins/scripts/provision-dev-databases.sh'
      }
    }

    stage('Deploy') {
      withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
        sh 'jenkins/scripts/deploy-helm.sh'
      }
    }

    stage('Smoke Test') {
      withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
        sh 'jenkins/scripts/smoke-test.sh'
      }
    }
  }
}
