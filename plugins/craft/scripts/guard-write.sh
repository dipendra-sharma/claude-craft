#!/bin/bash
set -uo pipefail

[ "${CLAUDE_CRAFT_RULES:-on}" = "off" ] && exit 0

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0
base=$(basename "$path")

deny() {
  printf 'Blocked: hand-editing %s.\n\n%s\n\nThe CLI is the only writer for this file. Editing a lockfile by hand is always wrong.\nNo CLI available, or offline? Re-run with CLAUDE_CRAFT_RULES=off prefixed and say why first.\n' "$base" "$1" >&2
  exit 2
}

case "$base" in
  package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lock|bun.lockb)
    deny 'Run the package manager and let it write the lock:  bun add <pkg>  /  bun remove <pkg>' ;;
  Cargo.lock)
    deny 'Run:  cargo add <crate>   /   cargo remove <crate>' ;;
  go.sum)
    deny 'Run:  go get <module>   then   go mod tidy' ;;
  poetry.lock|uv.lock|Pipfile.lock)
    deny 'Run:  uv add <pkg>   /   uv remove <pkg>' ;;
  pubspec.lock)
    deny 'Run:  flutter pub add <pkg>   /   flutter pub remove <pkg>' ;;
  Podfile.lock)
    deny 'Run:  pod install   /   pod update' ;;
  Gemfile.lock|composer.lock|gradle.lockfile)
    deny 'Run the ecosystem tool and let it regenerate the lock.' ;;

  package.json)
    deny 'Dependencies go in through the CLI:  bun add <pkg>   /   bun remove <pkg>
Never type a version number into this file — resolve it with  bun info <pkg> version.' ;;
  pyproject.toml|Pipfile)
    deny 'Run:  uv add <pkg>   /   uv remove <pkg>
Never bare python or pip.' ;;
  Cargo.toml)
    deny 'Run:  cargo add <crate>   /   cargo remove <crate>' ;;
  go.mod)
    deny 'Run:  go get <module>   /   go mod edit' ;;
  pubspec.yaml)
    deny 'Run:  flutter pub add <pkg>   (no pin — let it resolve the real current version)' ;;
  Podfile)
    deny 'Edit through CocoaPods, then:  pod install' ;;
  Gemfile)
    deny 'Run:  bundle add <gem>   /   bundle remove <gem>' ;;
  composer.json)
    deny 'Run:  composer require <pkg>   /   composer remove <pkg>' ;;
  build.gradle|build.gradle.kts|libs.versions.toml|settings.gradle|settings.gradle.kts)
    deny 'Gradle has no dependency-add CLI, so this one needs a deliberate call rather than a reflex edit.
Never type a version from memory: resolve it first, then state which registry you checked.' ;;
esac

exit 0
