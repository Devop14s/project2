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
    choice(
      name: 'SERVICE_CATALOG',
      choices: ['release-baseline', 'full'],
      description: 'Choose the first-release baseline subset or the full source-verified service catalog'
    )
    string(
      name: 'SOURCE_ROOT',
      defaultValue: '',
      description: 'Optional relative path to the checked-out YAS source tree; leave blank to auto-detect workspace root or yas-source/'
    )
    string(
      name: 'SOURCE_GIT_ROOT',
      defaultValue: '',
      description: 'Optional separate Git checkout used for branch and commit resolution'
    )
    string(
      name: 'DOCKERHUB_NAMESPACE',
      defaultValue: '',
      description: 'Docker registry namespace, for example docker.io/your-org'
    )
  }

  stages {
    stage('Dispatch') {
      steps {
        script {
          def dockerhubNamespace = params.DOCKERHUB_NAMESPACE?.trim()
          if (!dockerhubNamespace) {
            dockerhubNamespace = env.DOCKERHUB_NAMESPACE?.trim()
          }

          if (!dockerhubNamespace) {
            error('DOCKERHUB_NAMESPACE must be provided as a parameter or Jenkins job environment value.')
          }

          env.DOCKERHUB_NAMESPACE = dockerhubNamespace
          env.SERVICE_CATALOG = params.SERVICE_CATALOG
          env.SOURCE_ROOT = params.SOURCE_ROOT?.trim()
          env.SOURCE_GIT_ROOT = params.SOURCE_GIT_ROOT?.trim()
          env.SERVICES_FILE = [
            'release-baseline': 'jenkins/services.release-baseline.env',
            'full': 'jenkins/services.env'
          ][params.SERVICE_CATALOG]

          if (!env.SERVICES_FILE) {
            error("Unsupported SERVICE_CATALOG=${params.SERVICE_CATALOG}")
          }

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
