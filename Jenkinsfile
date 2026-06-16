pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    ansiColor('xterm')
  }

  parameters {
    choice(
      name: 'PIPELINE_TARGET',
      choices: ['ci', 'developer_build', 'developer_cleanup', 'dev_cd', 'staging_release', 'dev_gitops', 'staging_gitops'],
      description: 'Pipeline entrypoint to execute'
    )
    choice(
      name: 'SERVICE_CATALOG',
      choices: ['release-baseline', 'full'],
      description: 'Choose the first-release baseline subset or the full source-verified service catalog'
    )
    string(
      name: 'SOURCE_ROOT',
      defaultValue: '',
      description: 'Optional relative path to the checked-out YAS source tree; leave blank to auto-detect workspace root or yas-source/'
    )
    string(
      name: 'SOURCE_GIT_ROOT',
      defaultValue: '',
      description: 'Optional separate Git checkout used for branch and commit resolution'
    )
    string(
      name: 'DOCKERHUB_NAMESPACE',
      defaultValue: '',
      description: 'Docker registry namespace, for example docker.io/your-org'
    )
    string(
      name: 'RELEASE_VERSION',
      defaultValue: 'v1.0.0',
      description: 'Release tag used by staging pipelines and shared release flows'
    )
    string(
      name: 'DEPLOYER_ID',
      defaultValue: 'dev1',
      description: 'Developer identifier used by developer build and cleanup flows'
    )
    string(
      name: 'DOMAIN_NAME',
      defaultValue: 'storefront-dev1.yas.local',
      description: 'Optional storefront hostname override for developer flows'
    )
    string(
      name: 'BACKOFFICE_DOMAIN_NAME',
      defaultValue: 'backoffice-dev1.yas.local',
      description: 'Optional backoffice hostname override for developer flows'
    )
    string(
      name: 'NAMESPACE',
      defaultValue: '',
      description: 'Optional explicit namespace override for cleanup or manual deploy flows'
    )
    string(
      name: 'RELEASE_NAME',
      defaultValue: '',
      description: 'Optional explicit release-name override for cleanup or manual deploy flows'
    )
    booleanParam(
      name: 'DELETE_NAMESPACE',
      defaultValue: true,
      description: 'Delete the namespace after uninstall for developer cleanup flows'
    )
    booleanParam(
      name: 'ALLOW_SHARED_ENVIRONMENT_CLEANUP',
      defaultValue: false,
      description: 'Explicitly allow cleanup against shared dev/staging environments'
    )
    booleanParam(
      name: 'ALLOW_SHARED_NAMESPACE_DELETE',
      defaultValue: false,
      description: 'Explicitly allow namespace deletion for shared dev/staging cleanup targets'
    )
    string(name: 'STOREFRONT_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for storefront')
    string(name: 'BACKOFFICE_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for backoffice')
    string(name: 'STOREFRONT_BFF_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for storefront-bff')
    string(name: 'BACKOFFICE_BFF_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for backoffice-bff')
    string(name: 'PRODUCT_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for product')
    string(name: 'MEDIA_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for media')
    string(name: 'CART_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for cart')
    string(name: 'CUSTOMER_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for customer')
    string(name: 'RATING_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for rating')
    string(name: 'LOCATION_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for location')
    string(name: 'ORDER_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for order')
    string(name: 'INVENTORY_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for inventory')
    string(name: 'TAX_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for tax')
    string(name: 'SEARCH_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for search')
    string(name: 'PROMOTION_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for promotion')
    string(name: 'PAYMENT_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for payment')
    string(name: 'PAYMENT_PAYPAL_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for payment-paypal')
    string(name: 'RECOMMENDATION_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for recommendation')
    string(name: 'SAMPLEDATA_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for sampledata')
    string(name: 'WEBHOOK_BRANCH', defaultValue: 'main', description: 'Developer-build branch override for webhook')
  }

  stages {
    stage('Dispatch') {
      steps {
        script {
          def developerBuildTarget = params.PIPELINE_TARGET == 'developer_build'
          def developerCleanupTarget = params.PIPELINE_TARGET == 'developer_cleanup'
          def stagingReleaseTarget = params.PIPELINE_TARGET == 'staging_release'
          def stagingGitopsTarget = params.PIPELINE_TARGET == 'staging_gitops'
          def stagingTarget = stagingReleaseTarget || stagingGitopsTarget
          def pipelineRequiresDockerhubNamespace = [
            'ci',
            'developer_build',
            'dev_cd',
            'staging_release',
            'dev_gitops',
            'staging_gitops'
          ].contains(params.PIPELINE_TARGET)
          def dockerhubNamespace = params.DOCKERHUB_NAMESPACE?.trim()
          if (!dockerhubNamespace) {
            dockerhubNamespace = env.DOCKERHUB_NAMESPACE?.trim()
          }

          if (pipelineRequiresDockerhubNamespace && !dockerhubNamespace) {
            error('DOCKERHUB_NAMESPACE must be provided as a parameter or Jenkins job environment value.')
          }

          if (dockerhubNamespace) {
            env.DOCKERHUB_NAMESPACE = dockerhubNamespace
          }
          env.PIPELINE_DISPATCH_MODE = 'true'
          env.SERVICE_CATALOG = params.SERVICE_CATALOG
          def sourceRootParam = params.SOURCE_ROOT?.trim()
          if (!sourceRootParam) {
            sourceRootParam = 'yas-source'
          }

          if (!fileExists("${sourceRootParam}/.git")) {
            dir(sourceRootParam) {
              checkout([
                $class: 'GitSCM',
                branches: [[name: '*/main']],
                userRemoteConfigs: [[url: 'https://github.com/nashtech-garage/yas.git']]
              ])
            }
          }

          env.SOURCE_ROOT = sourceRootParam
          env.SOURCE_GIT_ROOT = params.SOURCE_GIT_ROOT?.trim()
          if (!env.SOURCE_GIT_ROOT) {
            env.SOURCE_GIT_ROOT = sourceRootParam
          }
          env.RELEASE_VERSION = stagingTarget ? (params.RELEASE_VERSION?.trim() ?: 'v1.0.0') : ''
          env.DEPLOYER_ID = (developerBuildTarget || developerCleanupTarget) ? (params.DEPLOYER_ID?.trim() ?: 'dev1') : ''
          env.DOMAIN_NAME = developerBuildTarget ? (params.DOMAIN_NAME?.trim() ?: "storefront-${env.DEPLOYER_ID}.yas.local") : ''
          env.BACKOFFICE_DOMAIN_NAME = developerBuildTarget ? (params.BACKOFFICE_DOMAIN_NAME?.trim() ?: "backoffice-${env.DEPLOYER_ID}.yas.local") : ''
          env.NAMESPACE = developerCleanupTarget ? (params.NAMESPACE?.trim() ?: '') : ''
          env.RELEASE_NAME = developerCleanupTarget ? (params.RELEASE_NAME?.trim() ?: '') : ''
          env.DELETE_NAMESPACE = developerCleanupTarget ? (params.DELETE_NAMESPACE ? '1' : '0') : ''
          env.ALLOW_SHARED_ENVIRONMENT_CLEANUP = developerCleanupTarget ? (params.ALLOW_SHARED_ENVIRONMENT_CLEANUP ? '1' : '0') : ''
          env.ALLOW_SHARED_NAMESPACE_DELETE = developerCleanupTarget ? (params.ALLOW_SHARED_NAMESPACE_DELETE ? '1' : '0') : ''

          [
            'STOREFRONT_BRANCH',
            'BACKOFFICE_BRANCH',
            'STOREFRONT_BFF_BRANCH',
            'BACKOFFICE_BFF_BRANCH',
            'PRODUCT_BRANCH',
            'MEDIA_BRANCH',
            'CART_BRANCH',
            'CUSTOMER_BRANCH',
            'RATING_BRANCH',
            'LOCATION_BRANCH',
            'ORDER_BRANCH',
            'INVENTORY_BRANCH',
            'TAX_BRANCH',
            'SEARCH_BRANCH',
            'PROMOTION_BRANCH',
            'PAYMENT_BRANCH',
            'PAYMENT_PAYPAL_BRANCH',
            'RECOMMENDATION_BRANCH',
            'SAMPLEDATA_BRANCH',
            'WEBHOOK_BRANCH'
          ].each { branchParam ->
            env."${branchParam}" = developerBuildTarget ? (params."${branchParam}"?.trim() ?: 'main') : ''
          }

          env.SERVICES_FILE = [
            'release-baseline': 'jenkins/services.release-baseline.env',
            'full': 'jenkins/services.env'
          ][params.SERVICE_CATALOG]

          if (!env.SERVICES_FILE) {
            error("Unsupported SERVICE_CATALOG=${params.SERVICE_CATALOG}")
          }

          def scriptPath = [
            ci: 'jenkins/pipelines/ci.groovy',
            developer_build: 'jenkins/pipelines/developer_build.groovy',
            developer_cleanup: 'jenkins/pipelines/developer_cleanup.groovy',
            dev_cd: 'jenkins/pipelines/dev_cd.groovy',
            staging_release: 'jenkins/pipelines/staging_release.groovy',
            dev_gitops: 'jenkins/pipelines/dev_gitops.groovy',
            staging_gitops: 'jenkins/pipelines/staging_gitops.groovy'
          ][params.PIPELINE_TARGET]

          if (!scriptPath) {
            error("Unsupported PIPELINE_TARGET=${params.PIPELINE_TARGET}")
          }

          def runner = load(scriptPath)
          runner()
        }
      }
    }
  }
}
