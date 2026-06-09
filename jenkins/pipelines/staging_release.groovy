return {
  properties([
    parameters([
      choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog to build, push, and deploy'),
      string(name: 'SOURCE_ROOT', defaultValue: '', description: 'Optional relative path to the YAS source tree; leave blank to auto-detect workspace root or yas-source/'),
      string(name: 'SOURCE_GIT_ROOT', defaultValue: '', description: 'Optional separate Git checkout used for commit resolution'),
      string(name: 'RELEASE_VERSION', defaultValue: 'v1.0.0', description: 'Version tag to build and deploy')
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
  }
}
