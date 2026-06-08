return {
  properties([
    parameters([
      string(name: 'RELEASE_VERSION', defaultValue: 'v1.0.0', description: 'Version tag to build and deploy')
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
