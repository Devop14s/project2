return {
  properties([
    parameters([
      string(name: 'DEPLOYER_ID', defaultValue: 'dev1', description: 'Developer identifier used in namespace and hostname'),
      string(name: 'DOMAIN_NAME', defaultValue: 'storefront-dev1.yas.local', description: 'Hostname shown to the developer'),
      string(name: 'TAX_BRANCH', defaultValue: 'main', description: 'Branch override for tax'),
      string(name: 'PRODUCT_BRANCH', defaultValue: 'main', description: 'Branch override for product'),
      string(name: 'STOREFRONT_BFF_BRANCH', defaultValue: 'main', description: 'Branch override for storefront-bff')
    ])
  ])

  node {
    stage('Checkout') {
      checkout scm
      sh 'mkdir -p work'
    }

    stage('Resolve Branch Tags') {
      sh '''
        export DEPLOYER_ID="${DEPLOYER_ID}"
        export DOMAIN_NAME="${DOMAIN_NAME}"
        export TAX_BRANCH="${TAX_BRANCH}"
        export PRODUCT_BRANCH="${PRODUCT_BRANCH}"
        export STOREFRONT_BFF_BRANCH="${STOREFRONT_BFF_BRANCH}"
        jenkins/scripts/resolve-branch-tags.sh
      '''
    }

    stage('Generate Values') {
      sh '''
        export DEPLOYER_ID="${DEPLOYER_ID}"
        export DOMAIN_NAME="${DOMAIN_NAME}"
        jenkins/scripts/generate-values.sh
      '''
    }

    stage('Deploy') {
      withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
        sh '''
          export DEPLOYER_ID="${DEPLOYER_ID}"
          export DOMAIN_NAME="${DOMAIN_NAME}"
          jenkins/scripts/deploy-helm.sh
        '''
      }
    }

    stage('Smoke Test') {
      withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
        sh '''
          export DEPLOYER_ID="${DEPLOYER_ID}"
          export DOMAIN_NAME="${DOMAIN_NAME}"
          jenkins/scripts/smoke-test.sh
        '''
      }
    }
  }
}
