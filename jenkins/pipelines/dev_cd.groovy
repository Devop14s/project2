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

    stage('Deploy Dev') {
      withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
        sh 'export ENVIRONMENT=dev; export RELEASE_NAME=yas-dev; export NAMESPACE=yas-dev; jenkins/scripts/generate-values.sh'
        sh 'export ENVIRONMENT=dev; export RELEASE_NAME=yas-dev; export NAMESPACE=yas-dev; jenkins/scripts/deploy-helm.sh'
      }
    }
  }
}
