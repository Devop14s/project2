pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    ansiColor('xterm')
  }

  parameters {
    choice(
      name: 'PIPELINE_TARGET',
      choices: ['ci', 'developer_build', 'developer_cleanup', 'dev_cd', 'staging_release', 'dev_gitops', 'staging_gitops'],
      description: 'Pipeline entrypoint to execute'
    )
  }

  environment {
    DOCKERHUB_NAMESPACE = 'replace-me'
  }

  stages {
    stage('Dispatch') {
      steps {
        script {
          def scriptPath = [
            ci: 'jenkins/pipelines/ci.groovy',
            developer_build: 'jenkins/pipelines/developer_build.groovy',
            developer_cleanup: 'jenkins/pipelines/developer_cleanup.groovy',
            dev_cd: 'jenkins/pipelines/dev_cd.groovy',
            staging_release: 'jenkins/pipelines/staging_release.groovy',
            dev_gitops: 'jenkins/pipelines/dev_gitops.groovy',
            staging_gitops: 'jenkins/pipelines/staging_gitops.groovy'
          ][params.PIPELINE_TARGET]

          if (!scriptPath) {
            error("Unsupported PIPELINE_TARGET=${params.PIPELINE_TARGET}")
          }

          def runner = load(scriptPath)
          runner()
        }
      }
    }
  }
}
