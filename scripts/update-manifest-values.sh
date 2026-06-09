#!/usr/bin/env sh
set -eu

if [ "$#" -ne 2 ]; then
  printf 'Usage: %s <values-file> <tag>\n' "$0" >&2
  exit 1
fi

values_file="$1"
tag="$2"
tmp_file="${TMPDIR:-/tmp}/manifest-values.$$"

[ -f "$values_file" ] || {
  printf 'Values file not found: %s\n' "$values_file" >&2
  exit 1
}

awk -v tag="$tag" '
  {
    current = $0
    sub(/\r$/, "", current)
    trimmed = current
    sub(/^[[:space:]]+/, "", trimmed)

    if (trimmed == "image:") {
      in_image = 1
      print current
      next
    }

    if (in_image && trimmed ~ /^tag:[[:space:]]*/) {
      indent = current
      sub(/tag:.*/, "", indent)
      printf "%stag: %s\n", indent, tag
      in_image = 0
      next
    }

    if (trimmed !~ /^$/ && trimmed !~ /^repository:/ && trimmed !~ /^pullPolicy:/ && trimmed !~ /^tag:/ && trimmed !~ /^image:/ && current !~ /^[[:space:]]/) {
      in_image = 0
    }

    print current
  }
' "$values_file" > "$tmp_file"

mv "$tmp_file" "$values_file"
printf 'Updated %s with tag %s\n' "$values_file" "$tag"
