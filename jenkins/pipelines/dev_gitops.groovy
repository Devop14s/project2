return {
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

    stage('Build And Push Main Images') {
      sh 'export RELEASE_VERSION=main; jenkins/scripts/build-images.sh'
      sh 'export RELEASE_VERSION=main; jenkins/scripts/push-images.sh'
    }

    stage('Update GitOps Values') {
      sh 'export ENVIRONMENT=dev; export VALUES_FILE=argocd/values/dev-values.yaml; jenkins/scripts/update-manifest-repo.sh'
    }
  }
}

