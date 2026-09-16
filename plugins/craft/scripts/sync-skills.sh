#!/bin/bash
set -uo pipefail

plugin_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="${1:-$HOME/.claude/skills}"

if [ ! -d "$source_dir" ]; then
  printf 'No such source directory: %s\n' "$source_dir" >&2
  exit 1
fi

cd "$plugin_root"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'Refusing to sync outside a git repository: replaced files would not be recoverable.\n' >&2
  exit 1
fi

trash_bin=$(command -v trash || true)
holding=""
if [ -z "$trash_bin" ]; then
  holding="${TMPDIR:-/tmp}/craft-sync-removed-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$holding"
  printf 'No trash command on this system. Files this sync removes will be moved to %s instead of deleted.\n\n' "$holding"
fi

changed=0
missing=0
same=0

for dir in skills/*/; do
  name=$(basename "$dir")
  src="$source_dir/$name"

  if [ ! -d "$src" ]; then
    printf '  missing  %-34s not in %s\n' "$name" "$source_dir"
    missing=$((missing + 1))
    continue
  fi

  if diff -rq "$dir" "$src" >/dev/null 2>&1; then
    same=$((same + 1))
    continue
  fi

  removed=$(comm -23 \
    <(cd "$dir" && find . -type f | sort) \
    <(cd "$src" && find . -type f | sort))

  if [ -n "$removed" ]; then
    while IFS= read -r stale; do
      [ -n "$stale" ] || continue
      if [ -n "$trash_bin" ]; then
        "$trash_bin" "$dir/${stale#./}"
        printf '  trashed  %s/%s\n' "$name" "${stale#./}"
      else
        mv "$dir/${stale#./}" "$holding/"
        printf '  held     %s/%s  (moved to %s)\n' "$name" "${stale#./}" "$holding"
      fi
    done <<< "$removed"
  fi

  cp -R "$src/." "$dir/"
  printf '  synced   %s\n' "$name"
  changed=$((changed + 1))
done

printf '\n%s synced, %s already current, %s missing from source\n' "$changed" "$same" "$missing"

if [ "$changed" -gt 0 ]; then
  printf 'Review with: git -C %s diff -- plugins/*/skills\n' "$(git rev-parse --show-toplevel)"
fi
