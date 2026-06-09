return {
  node {
    stage('Checkout') {
      checkout scm
      sh 'mkdir -p work'
    }

    stage('Resolve Commit Metadata') {
      sh 'git rev-parse HEAD > work/commit_sha.txt'
      sh 'git rev-parse --short HEAD > work/commit_short_sha.txt'
    }

    stage('Docker Login') {
      withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
        sh 'jenkins/scripts/docker-login.sh'
      }
    }

    stage('Build Images') {
      sh 'jenkins/scripts/build-images.sh'
    }

    stage('Push Images') {
      sh 'jenkins/scripts/push-images.sh'
    }
  }
}

