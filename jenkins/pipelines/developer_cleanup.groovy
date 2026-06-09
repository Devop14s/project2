return {
  if (env.PIPELINE_DISPATCH_MODE != 'true') {
    properties([
      parameters([
        string(name: 'DEPLOYER_ID', defaultValue: 'dev1', description: 'Developer identifier used in namespace and release name'),
        choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog associated with the deployment being cleaned up'),
        string(name: 'NAMESPACE', defaultValue: '', description: 'Optional explicit namespace'),
        string(name: 'RELEASE_NAME', defaultValue: '', description: 'Optional explicit release name'),
        booleanParam(name: 'DELETE_NAMESPACE', defaultValue: true, description: 'Delete the namespace after uninstall for developer environments'),
        booleanParam(name: 'ALLOW_SHARED_ENVIRONMENT_CLEANUP', defaultValue: false, description: 'Required to clean up shared dev/staging environments intentionally'),
        booleanParam(name: 'ALLOW_SHARED_NAMESPACE_DELETE', defaultValue: false, description: 'Required in addition to delete the namespace for shared dev/staging targets')
      ])
    ])
  }

  node {
    stage('Checkout') {
      checkout scm
    }

    stage('Cleanup') {
      withCredentials([file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')]) {
        sh '''
          export DEPLOYER_ID="${DEPLOYER_ID}"
          export NAMESPACE="${NAMESPACE}"
          export RELEASE_NAME="${RELEASE_NAME}"
          export DELETE_NAMESPACE="${DELETE_NAMESPACE}"
          export ALLOW_SHARED_ENVIRONMENT_CLEANUP="${ALLOW_SHARED_ENVIRONMENT_CLEANUP}"
          export ALLOW_SHARED_NAMESPACE_DELETE="${ALLOW_SHARED_NAMESPACE_DELETE}"
          jenkins/scripts/cleanup-release.sh
        '''
      }
    }
  }
}
