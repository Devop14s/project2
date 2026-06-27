return {
  if (env.PIPELINE_DISPATCH_MODE != 'true') {
    properties([
      parameters([
        choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog to build and push'),
        string(name: 'DOCKERHUB_NAMESPACE', defaultValue: '', description: 'Docker registry namespace, for example docker.io/your-org'),
        string(name: 'SOURCE_ROOT', defaultValue: '', description: 'Optional relative path to the YAS source tree; leave blank to clone or reuse yas-source-upstream/ automatically'),
        string(name: 'SOURCE_GIT_ROOT', defaultValue: '', description: 'Optional separate Git checkout used for commit resolution'),
        string(name: 'SOURCE_REPO_URL', defaultValue: 'https://github.com/nashtech-garage/yas.git', description: 'Source repository URL used when the job must clone YAS on demand'),
        string(name: 'SOURCE_REPO_REF', defaultValue: 'main', description: 'Source branch, tag, or ref used when the job must clone YAS on demand')
      ])
    ])
  }

  node {
    try {
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

      stage('Resolve Commit Metadata') {
        sh 'jenkins/scripts/write-commit-metadata.sh'
        env.RELEASE_VERSION = readFile('work/commit_short_sha.txt').trim()
        echo "Resolved image tag: ${env.RELEASE_VERSION}"
      }

      stage('Docker Login') {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'jenkins/scripts/docker-login.sh'
        }
      }

      stage('Maven Build') {
        sh 'jenkins/scripts/maven-build.sh'
      }

      stage('Build Images') {
        sh 'jenkins/scripts/build-images.sh'
      }

      stage('Push Images') {
        sh 'jenkins/scripts/push-images.sh'
      }

      stage('Verify Image Tags') {
        sh 'jenkins/scripts/verify-image-tags.sh'
      }
    } finally {
      sh 'docker logout || true'
      archiveArtifacts artifacts: 'work/**', allowEmptyArchive: true
    }
  }
}
