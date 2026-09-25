#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
locks='package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lock|bun.lockb|Cargo.lock|go.sum|poetry.lock|uv.lock|pdm.lock|Pipfile.lock|pubspec.lock|Podfile.lock|Gemfile.lock|composer.lock|gradle.lockfile|Package.resolved'
manifests='package.json|pyproject.toml|Pipfile|Cargo.toml|go.mod|pubspec.yaml|Podfile|Gemfile|composer.json'

deny() {
  printf 'Blocked: %s\n\nUse the package manager: bun/npm/pnpm/yarn add, uv/poetry add, cargo add, go get, flutter pub add,\nbundle add, composer require, pod install. It resolves the real current version and writes the lockfile.\n\n%s\n' "$1" "$2" >&2
  exit 2
}

if [ "$(jq -r '.tool_name' <<< "$input")" = Bash ]; then
  cmd=$(jq -r '.tool_input.command // empty' <<< "$input")
  [[ "$cmd" =~ ^[[:space:]]*CLAUDE_CRAFT_RULES=off[[:space:]] ]] && exit 0
  names="${locks//./\\.}|${manifests//./\\.}"
  grep -qE "(>|tee|sed[^;|&]*-i|perl[^;|&]*-[a-z]*i)([^;|&<>]*[[:space:]/'\"])?($names)([[:space:]'\";|&)]|$)" <<< "$cmd" || exit 0
  deny "a shell write to a manifest or lockfile." "Genuine exception? Say why, then re-run with CLAUDE_CRAFT_RULES=off as the first word."
fi

path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<< "$input")
base=${path##*/}
[[ "|$locks|$manifests|" == *"|$base|"* ]] || exit 0
awk -F '\t' -v key="$path" -v now="$(date +%s)" '$2 == key && now - $1 <= 1800 { found = 1 } END { exit !found }' \
  "$(craft_allow_file)" 2>/dev/null && exit 0
hatch="Genuine exception (no CLI, offline)? Say why, then run  craft-allow $path  and retry."

[[ "|$locks|" == *"|$base|"* ]] && deny "hand-editing $base. A lockfile is only ever written by its package manager." "$hatch"
[ -f "$path" ] || deny "creating $base by hand. Scaffold the project with its init command: bun init, uv init, cargo init, go mod init, flutter create." "$hatch"

json_dependencies() {
  jq -Rsr 'try (fromjson | {dependencies, devDependencies, peerDependencies, optionalDependencies, bundleDependencies, bundledDependencies, overrides, resolutions, packageManager, require, "require-dev"} | to_entries[] | select(.value != null) | "\(.key)\t\(.value | tojson)") catch empty'
}

toml_dependencies() {
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function is_dep(t) { return t ~ /(^|\.)(dependencies|dev-dependencies|build-dependencies|packages|dev-packages|dependency-groups|optional-dependencies)(\.|$)/ }
    /^[ \t]*\[/ { table = trim($0); gsub(/^\[+|\]+.*$/, "", table); in_array = 0; if (is_dep(table)) print table "\t" trim($0); next }
    trim($0) == "" { next }
    in_array { print table "\t" trim($0); if (trim($0) ~ /^\]/) in_array = 0; next }
    is_dep(table) { print table "\t" trim($0); next }
    /^[ \t]*[A-Za-z0-9_-]*dependencies[ \t]*=/ { print table "\t" trim($0); if ($0 ~ /\[/ && $0 !~ /\][ \t]*$/) in_array = 1 }
  '
}

pubspec_dependencies() {
  awk '/^[A-Za-z_]+:/ { key = $0; sub(/:.*/, "", key) }
    key ~ /^(dependencies|dev_dependencies|dependency_overrides)$/ { line = $0; gsub(/^[ \t]+|[ \t]+$/, "", line); if (line != "") print key "\t" line }'
}

dependencies() {
  case "$base" in
    package.json|composer.json) json_dependencies ;;
    Cargo.toml|pyproject.toml|Pipfile) toml_dependencies ;;
    pubspec.yaml) pubspec_dependencies ;;
    go.mod) sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' ;;
    Gemfile) grep -E '^[[:space:]]*gem[[:space:](]' ;;
    Podfile) grep -E '^[[:space:]]*pod[[:space:](]' ;;
  esac
}

edited_text() {
  jq -r --rawfile file "$path" '
    def apply($e):
      if ($e.old_string // "") == "" then .
      elif ($e.replace_all // false) then split($e.old_string) | join($e.new_string)
      else split($e.old_string) as $parts
        | if ($parts | length) < 2 then . else $parts[0] + $e.new_string + ($parts[1:] | join($e.old_string)) end
      end;
    .tool_input as $t
    | if $t.content != null then $t.content
      elif $t.edits != null then reduce $t.edits[] as $e ($file; apply($e))
      else $file | apply($t)
      end' <<< "$input"
}

[ "$(dependencies < "$path" | sort)" = "$(edited_text | dependencies | sort)" ] && exit 0
deny "this edit changes the dependencies in $base. Edits outside the dependency sections (scripts, assets,
settings, the package's own version) are fine." "$hatch"
