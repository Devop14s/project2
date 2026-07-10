boolean isAbsolutePath(String path) {
  if (!path) {
    return false
  }

  return path.startsWith('/') || path ==~ /^[A-Za-z]:[\\\/].*/
}

String branchSpecFor(String sourceRepoRef) {
  if (!sourceRepoRef) {
    return '*/main'
  }

  if (sourceRepoRef.startsWith('refs/')) {
    return sourceRepoRef
  }

  return "*/${sourceRepoRef}"
}

Map ensureSourceCheckout(Map options = [:]) {
  String sourceRootParam = options.sourceRootParam?.trim()
  if (!sourceRootParam) {
    sourceRootParam = 'yas-source-upstream'
  }

  String sourceGitRootParam = options.sourceGitRootParam?.trim()
  String sourceRepoUrl = options.sourceRepoUrl?.trim()
  if (!sourceRepoUrl) {
    sourceRepoUrl = 'https://github.com/nashtech-garage/yas.git'
  }

  String sourceRepoRef = options.sourceRepoRef?.trim()
  if (!sourceRepoRef) {
    sourceRepoRef = 'main'
  }

  String workspaceRoot = pwd()
  String sourceRootPath = isAbsolutePath(sourceRootParam) ? sourceRootParam : "${workspaceRoot}/${sourceRootParam}"

  if (sourceGitRootParam && fileExists(sourceRootPath)) {
    echo "Using existing source root ${sourceRootPath} with separate Git root ${sourceGitRootParam}"
  } else if (!fileExists("${sourceRootPath}/.git")) {
    echo "Bootstrapping YAS source checkout into ${sourceRootPath} from ${sourceRepoUrl} (${sourceRepoRef})"
    dir(sourceRootPath) {
      checkout([
        $class: 'GitSCM',
        branches: [[name: branchSpecFor(sourceRepoRef)]],
        userRemoteConfigs: [[url: sourceRepoUrl]]
      ])
    }
  }

  String sourceGitRoot = sourceGitRootParam ?: sourceRootPath
  return [
    sourceRoot: sourceRootPath,
    sourceGitRoot: sourceGitRoot,
    sourceRepoUrl: sourceRepoUrl,
    sourceRepoRef: sourceRepoRef
  ]
}

return this
