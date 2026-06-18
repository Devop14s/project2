return {
  if (env.PIPELINE_DISPATCH_MODE != 'true') {
    properties([
      parameters([
        choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog to build, push, and deploy'),
        string(name: 'DOCKERHUB_NAMESPACE', defaultValue: '', description: 'Docker registry namespace, for example docker.io/your-org'),
        string(name: 'SOURCE_ROOT', defaultValue: '', description: 'Optional relative path to the YAS source tree; leave blank to clone or reuse yas-source-upstream/ automatically'),
        string(name: 'SOURCE_GIT_ROOT', defaultValue: '', description: 'Optional separate Git checkout used for commit resolution'),
        string(name: 'SOURCE_REPO_URL', defaultValue: 'https://github.com/nashtech-garage/yas.git', description: 'Source repository URL used when the job must clone YAS on demand'),
        string(name: 'SOURCE_REPO_REF', defaultValue: 'main', description: 'Source branch, tag, or ref used when the job must clone YAS on demand'),
        string(name: 'RELEASE_VERSION', defaultValue: 'v1.0.0', description: 'Version tag to build and deploy')
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
      env.SOURCE_REPO_URL = env.SOURCE_REPO_URL?.trim() ?: params.SOURCE_REPO_URL?.trim() ?: 'https://github.com/nashtech-garage/yas.git'
      env.SOURCE_REPO_REF = env.SOURCE_REPO_REF?.trim() ?: params.SOURCE_REPO_REF?.trim() ?: 'main'
      def sourceContext = sourceBootstrap.ensureSourceCheckout(
        sourceRootParam: env.SOURCE_ROOT?.trim() ?: params.SOURCE_ROOT?.trim(),
        sourceGitRootParam: env.SOURCE_GIT_ROOT?.trim() ?: params.SOURCE_GIT_ROOT?.trim(),
        sourceRepoUrl: env.SOURCE_REPO_URL,
        sourceRepoRef: env.SOURCE_REPO_REF
      )
      env.SOURCE_ROOT = sourceContext.sourceRoot
      env.SOURCE_GIT_ROOT = sourceContext.sourceGitRoot
      if (!env.DOCKERHUB_NAMESPACE) {
        error('DOCKERHUB_NAMESPACE must be provided as a parameter or Jenkins job environment value.')
      }
    }

    stage('Docker Login') {
      withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
        sh 'jenkins/scripts/docker-login.sh'
      }
    }

    stage('Resolve Commit Metadata') {
      sh 'jenkins/scripts/write-commit-metadata.sh'
    }

    stage('Build And Push Release Images') {
      sh '''
        export RELEASE_VERSION="${RELEASE_VERSION}"
        jenkins/scripts/build-images.sh
        jenkins/scripts/push-images.sh
      '''
    }

    stage('Deploy Staging') {
      withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
        sh '''
          export ENVIRONMENT=staging
          export RELEASE_VERSION="${RELEASE_VERSION}"
          export RELEASE_NAME=yas-staging
          export NAMESPACE=yas-staging
          jenkins/scripts/generate-values.sh
          jenkins/scripts/deploy-helm.sh
        '''
      }
    }

    stage('Smoke Test Staging') {
      withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
        sh '''
          export ENVIRONMENT=staging
          export RELEASE_VERSION="${RELEASE_VERSION}"
          export RELEASE_NAME=yas-staging
          export NAMESPACE=yas-staging
          jenkins/scripts/smoke-test.sh
        '''
      }
    }
  }
}
