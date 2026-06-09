return {
  properties([
    parameters([
      string(name: 'RELEASE_VERSION', defaultValue: 'v1.0.0', description: 'Version tag to publish into GitOps values')
    ])
  ])

  node {
    stage('Checkout') {
      checkout scm
      sh 'mkdir -p work'
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

