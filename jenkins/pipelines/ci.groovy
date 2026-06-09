return {
  if (env.PIPELINE_DISPATCH_MODE != 'true') {
    properties([
      parameters([
        choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog to build and push'),
        string(name: 'SOURCE_ROOT', defaultValue: '', description: 'Optional relative path to the YAS source tree; leave blank to auto-detect workspace root or yas-source/'),
        string(name: 'SOURCE_GIT_ROOT', defaultValue: '', description: 'Optional separate Git checkout used for commit resolution')
      ])
    ])
  }

  node {
    stage('Checkout') {
      checkout scm
      sh 'mkdir -p work'
      env.SERVICE_CATALOG = env.SERVICE_CATALOG?.trim() ?: 'full'
      env.SOURCE_ROOT = env.SOURCE_ROOT?.trim()
      env.SOURCE_GIT_ROOT = env.SOURCE_GIT_ROOT?.trim()
    }

    stage('Resolve Commit Metadata') {
      sh 'jenkins/scripts/write-commit-metadata.sh'
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

