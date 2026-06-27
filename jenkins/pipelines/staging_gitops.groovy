return {
  if (env.PIPELINE_DISPATCH_MODE != 'true') {
    properties([
      parameters([
        choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog to publish into GitOps values'),
        string(name: 'DOCKERHUB_NAMESPACE', defaultValue: 'luongtrz', description: 'Docker registry namespace (images already built and pushed by CI)'),
        string(name: 'RELEASE_VERSION', defaultValue: 'v1.0.0', description: 'Version tag to publish into GitOps values'),
      ])
    ])
  }

  node {
    stage('Checkout') {
      checkout scm
      sh 'mkdir -p work'
      env.SERVICE_CATALOG = env.SERVICE_CATALOG?.trim() ?: params.SERVICE_CATALOG?.trim() ?: 'release-baseline'
      env.DOCKERHUB_NAMESPACE = env.DOCKERHUB_NAMESPACE?.trim() ?: params.DOCKERHUB_NAMESPACE?.trim() ?: 'luongtrz'
      env.RELEASE_VERSION = env.RELEASE_VERSION?.trim() ?: params.RELEASE_VERSION?.trim() ?: 'v1.0.0'
    }

    stage('Update GitOps Values') {
      withCredentials([usernamePassword(
        credentialsId: 'github-pat-yas',
        usernameVariable: 'GIT_USER',
        passwordVariable: 'GIT_TOKEN'
      )]) {
        sh """
          git remote set-url origin https://\${GIT_USER}:\${GIT_TOKEN}@github.com/Devop14s/project2.git
          export SOURCE_ROOT=""
          export SOURCE_GIT_ROOT=""
          export ENVIRONMENT=staging
          export RELEASE_VERSION=\${RELEASE_VERSION}
          export DOCKERHUB_NAMESPACE=\${DOCKERHUB_NAMESPACE}
          export VALUES_FILE=argocd/values/staging-values.yaml
          export SERVICE_CATALOG=\${SERVICE_CATALOG}
          jenkins/scripts/update-manifest-repo.sh
        """
      }
    }
  }
}
