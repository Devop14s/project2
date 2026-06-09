return {
  properties([
    parameters([
      string(name: 'DEPLOYER_ID', defaultValue: 'dev1', description: 'Developer identifier used in namespace and hostname'),
      choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog to build and deploy'),
      string(name: 'SOURCE_ROOT', defaultValue: '', description: 'Optional relative path to the YAS source tree; leave blank to auto-detect workspace root or yas-source/'),
      string(name: 'SOURCE_GIT_ROOT', defaultValue: '', description: 'Optional separate Git checkout used for branch resolution'),
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

  node {
    stage('Checkout') {
      checkout scm
      sh 'mkdir -p work'
      env.SERVICE_CATALOG = env.SERVICE_CATALOG?.trim() ?: 'full'
      env.SOURCE_ROOT = env.SOURCE_ROOT?.trim()
      env.SOURCE_GIT_ROOT = env.SOURCE_GIT_ROOT?.trim()
    }

    stage('Resolve Branch Tags') {
      sh 'jenkins/scripts/resolve-branch-tags.sh'
    }

    stage('Generate Values') {
      sh 'jenkins/scripts/generate-values.sh'
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
