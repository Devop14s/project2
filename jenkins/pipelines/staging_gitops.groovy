return {
  if (env.PIPELINE_DISPATCH_MODE != 'true') {
    properties([
      parameters([
        choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog to build, push, and publish into GitOps values'),
        string(name: 'DOCKERHUB_NAMESPACE', defaultValue: '', description: 'Docker registry namespace, for example docker.io/your-org'),
        string(name: 'SOURCE_ROOT', defaultValue: '', description: 'Optional relative path to the YAS source tree; leave blank to auto-detect workspace root or yas-source/'),
        string(name: 'SOURCE_GIT_ROOT', defaultValue: '', description: 'Optional separate Git checkout used for commit resolution'),
        string(name: 'RELEASE_VERSION', defaultValue: 'v1.0.0', description: 'Version tag to publish into GitOps values')
      ])
    ])
  }

  node {
    stage('Checkout') {
      checkout scm
      sh 'mkdir -p work'
      env.SERVICE_CATALOG = env.SERVICE_CATALOG?.trim() ?: 'full'
      env.DOCKERHUB_NAMESPACE = env.DOCKERHUB_NAMESPACE?.trim() ?: params.DOCKERHUB_NAMESPACE?.trim()
      env.SOURCE_ROOT = env.SOURCE_ROOT?.trim()
      env.SOURCE_GIT_ROOT = env.SOURCE_GIT_ROOT?.trim()
      if (!env.DOCKERHUB_NAMESPACE) {
        error('DOCKERHUB_NAMESPACE must be provided as a parameter or Jenkins job environment value.')
      }
    }

    stage('Docker Login') {
      withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
        sh 'jenkins/scripts/docker-login.sh'
      }
    }

    stage('Build And Push Release Images') {
      sh '''
        export RELEASE_VERSION="${RELEASE_VERSION}"
        jenkins/scripts/build-images.sh
        jenkins/scripts/push-images.sh
      '''
    }

    stage('Update GitOps Values') {
      sh '''
        export ENVIRONMENT=staging
        export RELEASE_VERSION="${RELEASE_VERSION}"
        export VALUES_FILE=argocd/values/staging-values.yaml
        jenkins/scripts/update-manifest-repo.sh
      '''
    }
  }
}

