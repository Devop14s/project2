#!/usr/bin/env sh
set -eu

. scripts/source-root.sh

output_file="${1:-work/host-capabilities.generated.md}"
mkdir -p "$(dirname "$output_file")"

get_helm_path() {
  if command -v helm >/dev/null 2>&1; then
    command -v helm
    return 0
  fi
  find work/tools -type f -name helm.exe 2>/dev/null | head -n 1 || true
}

get_command_summary() {
  name="$1"
  explicit_path="${2:-}"

  resolved_path="$explicit_path"
  if [ -z "$resolved_path" ] && command -v "$name" >/dev/null 2>&1; then
    resolved_path="$(command -v "$name")"
  fi

  if [ -z "$resolved_path" ]; then
    printf 'missing||'
    return 0
  fi

  version=''
  case "$name" in
    docker)
      version="$("$resolved_path" --version 2>/dev/null | head -n 1 || true)"
      ;;
    kubectl)
      version="$("$resolved_path" version --client --output=yaml 2>/dev/null | awk '/gitVersion:/ { print; exit }' || true)"
      ;;
    helm)
      version="$("$resolved_path" version --template '{{.Version}}' 2>/dev/null | head -n 1 || true)"
      ;;
    *)
      version="$("$resolved_path" --version 2>/dev/null | head -n 1 || true)"
      ;;
  esac

  printf 'present|%s|%s' "$resolved_path" "$version"
}

helm_path="$(get_helm_path)"
git_summary="$(get_command_summary git)"
docker_summary="$(get_command_summary docker)"
kubectl_summary="$(get_command_summary kubectl)"
helm_summary="$(get_command_summary helm "$helm_path")"
java_summary="$(get_command_summary java)"
mvn_summary="$(get_command_summary mvn)"
node_summary="$(get_command_summary node)"
npm_summary="$(get_command_summary npm)"
powershell_summary="$(get_command_summary powershell)"
sh_summary="$(get_command_summary sh)"

docker_status="$(printf '%s' "$docker_summary" | cut -d'|' -f1)"
docker_daemon_reachable=0
resolved_source_root="$(resolve_source_root)"
if [ "$docker_status" = "present" ] && docker version >/dev/null 2>&1; then
  docker_daemon_reachable=1
fi

emit_tool_line() {
  name="$1"
  summary="$2"
  status="$(printf '%s' "$summary" | cut -d'|' -f1)"
  path="$(printf '%s' "$summary" | cut -d'|' -f2)"
  version="$(printf '%s' "$summary" | cut -d'|' -f3-)"

  if [ "$status" = "present" ]; then
    printf -- '- `%s`: present' "$name"
    if [ -n "$version" ]; then
      printf ' (%s)' "$version"
    fi
    if [ -n "$path" ]; then
      printf ' at `%s`' "$path"
    fi
    printf '\n'
  else
    printf -- '- `%s`: missing\n' "$name"
  fi
}

{
  printf '# Host Capabilities Report\n\n'
  printf 'Generated at: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf '## Tool Availability\n'
  emit_tool_line git "$git_summary"
  emit_tool_line docker "$docker_summary"
  emit_tool_line kubectl "$kubectl_summary"
  emit_tool_line helm "$helm_summary"
  emit_tool_line java "$java_summary"
  emit_tool_line mvn "$mvn_summary"
  emit_tool_line node "$node_summary"
  emit_tool_line npm "$npm_summary"
  emit_tool_line powershell "$powershell_summary"
  emit_tool_line sh "$sh_summary"
  printf '\n'
  printf '## Runtime Reachability\n'
  if [ "$docker_status" = "present" ]; then
    if [ "$docker_daemon_reachable" -eq 1 ]; then
      printf '%s\n' '- Docker daemon: reachable'
    else
      printf '%s\n' '- Docker daemon: unreachable from the current execution context'
    fi
  else
    printf '%s\n' '- Docker daemon: not checked because the Docker CLI is missing'
  fi
  printf '\n'
  printf '## Workspace Inputs\n'
  if [ -e "$resolved_source_root" ]; then
    printf '%s%s%s\n' '- Default resolved source root: `' "$resolved_source_root" '` (present)'
  else
    printf '%s%s%s\n' '- Default resolved source root: `' "$resolved_source_root" '` (missing)'
  fi
  [ -d yas-source-upstream ] && printf '%s\n' '- `yas-source-upstream/`: present' || printf '%s\n' '- `yas-source-upstream/`: missing'
  [ -d yas-source ] && printf '%s\n' '- `yas-source/`: present' || printf '%s\n' '- `yas-source/`: missing'
  [ -f jenkins/services.env ] && printf '%s\n' '- `jenkins/services.env`: present' || printf '%s\n' '- `jenkins/services.env`: missing'
  [ -f jenkins/services.release-baseline.env ] && printf '%s\n' '- `jenkins/services.release-baseline.env`: present' || printf '%s\n' '- `jenkins/services.release-baseline.env`: missing'
  [ -n "$helm_path" ] && printf '%s\n' '- Portable Helm under `work/tools/`: present' || printf '%s\n' '- Portable Helm under `work/tools/`: missing'
  printf '\n'
  printf '## Generated Evidence Snapshot\n'
  [ -f work/status-report.generated.md ] && printf '%s\n' '- `work/status-report.generated.md`: present' || printf '%s\n' '- `work/status-report.generated.md`: missing'
  [ -f work/service-verification.generated.md ] && printf '%s\n' '- `work/service-verification.generated.md`: present' || printf '%s\n' '- `work/service-verification.generated.md`: missing'
  [ -f work/final-report-notes.generated.md ] && printf '%s\n' '- `work/final-report-notes.generated.md`: present' || printf '%s\n' '- `work/final-report-notes.generated.md`: missing'
  printf '\n'
  printf '## Interpretation\n'
  printf '%s\n' '- This file records what the current host can and cannot do before real Jenkins, registry, and cluster infrastructure are attached.'
  printf '%s\n' '- Use it together with `work/status-report.generated.md` to distinguish repo-complete work from environment-complete work.'
} > "$output_file"

printf 'Generated host capabilities report: %s\n' "$output_file"
