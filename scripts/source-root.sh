#!/usr/bin/env sh

resolve_source_root() {
  if [ -n "${SOURCE_ROOT:-}" ]; then
    printf '%s' "$SOURCE_ROOT"
    return
  fi

  if [ -d "yas-source-upstream" ]; then
    printf 'yas-source-upstream'
    return
  fi

  if [ -d "yas-source" ]; then
    printf 'yas-source'
    return
  fi

  printf '.'
}

resolve_source_git_root() {
  if [ -n "${SOURCE_GIT_ROOT:-}" ]; then
    printf '%s' "$SOURCE_GIT_ROOT"
    return
  fi

  source_root="$(resolve_source_root)"
  if [ -d "${source_root}/.git" ]; then
    printf '%s' "$source_root"
    return
  fi

  printf '.'
}
