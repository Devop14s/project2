return {
  if (env.PIPELINE_DISPATCH_MODE != 'true') {
    properties([
      parameters([
        string(name: 'DEPLOYER_ID', defaultValue: 'dev1', description: 'Developer identifier used in namespace and release name'),
        choice(name: 'SERVICE_CATALOG', choices: ['release-baseline', 'full'], description: 'Service catalog associated with the deployment being cleaned up'),
        string(name: 'NAMESPACE', defaultValue: '', description: 'Optional explicit namespace'),
        string(name: 'RELEASE_NAME', defaultValue: '', description: 'Optional explicit release name')
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
          jenkins/scripts/cleanup-release.sh
        '''
      }
    }
  }
}
