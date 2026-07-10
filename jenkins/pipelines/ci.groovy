return {
  if (env.PIPELINE_DISPATCH_MODE != 'true') {
    properties([
      parameters([
        choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog to build and push'),
        string(name: 'DOCKERHUB_NAMESPACE', defaultValue: '', description: 'Docker registry namespace, for example docker.io/your-org'),
        string(name: 'SOURCE_ROOT', defaultValue: 'yas-source', description: 'Relative path to the YAS source tree inside this repository'),
        string(name: 'SOURCE_GIT_ROOT', defaultValue: '.', description: 'Git checkout used for commit resolution'),
        string(name: 'SOURCE_REPO_URL', defaultValue: 'https://github.com/Devop14s/yas-group14.git', description: 'Source repository URL used when the job must clone YAS on demand'),
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
        env.SOURCE_REPO_URL = env.SOURCE_REPO_URL?.trim() ?: params.SOURCE_REPO_URL?.trim() ?: 'https://github.com/Devop14s/yas-group14.git'
        env.SOURCE_REPO_REF = env.SOURCE_REPO_REF?.trim() ?: params.SOURCE_REPO_REF?.trim() ?: 'main'
        def sourceContext = sourceBootstrap.ensureSourceCheckout(
          sourceRootParam: env.SOURCE_ROOT?.trim() ?: params.SOURCE_ROOT?.trim() ?: 'yas-source',
          sourceGitRootParam: env.SOURCE_GIT_ROOT?.trim() ?: params.SOURCE_GIT_ROOT?.trim() ?: '.',
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
        def sourceBranch = env.BRANCH_NAME?.trim() ?: env.SOURCE_REPO_REF?.trim()
        env.RELEASE_VERSION = sourceBranch == 'main' ? 'main' : readFile('work/commit_short_sha.txt').trim()
        echo "Resolved image tag: ${env.RELEASE_VERSION}"
      }

      stage('Select Changed Services') {
        sh 'jenkins/scripts/select-changed-services.sh'
        env.SERVICES_FILE = readFile('work/ci-services-file.txt').trim()
        echo "CI service selection: ${env.SERVICES_FILE}"
      }

      stage('Docker Login') {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'jenkins/scripts/docker-login.sh'
        }
      }

      stage('Prepare Custom Dockerfiles') {
        sh """
          mkdir -p \${SOURCE_ROOT}/swagger-ui
          cp docker/swagger-ui/Dockerfile \${SOURCE_ROOT}/swagger-ui/Dockerfile
        """
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
