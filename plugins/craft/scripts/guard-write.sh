#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0
base=${path##*/}
kind=$(manifest_kind "$base")
[ -n "$kind" ] || exit 0
craft_is_allowed "$path" && exit 0

deny() {
  printf 'Blocked: hand-editing %s.\n\n%s\n\n%s\n\nGenuine exception (no CLI, offline)? Say why, then run  craft-allow %s  and retry.\n' \
    "$base" "$1" "$(manifest_hint "$base" "$(dirname "$path")")" "$path" >&2
  exit 2
}

json_dependency_view() {
  jq -Rsr 'try (fromjson | {dependencies, devDependencies, peerDependencies, optionalDependencies, bundleDependencies, bundledDependencies, overrides, resolutions, packageManager, require, "require-dev"} | to_entries[] | select(.value != null) | "\(.key)\t\(.value | tojson)") catch empty' 2>/dev/null
}

toml_dependency_view() {
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^[ \t]*\[/ {
      table = trim($0); gsub(/^\[+|\]+.*$/, "", table)
      in_array = 0
      if (table ~ /(^|\.)(dependencies|dev-dependencies|build-dependencies|packages|dev-packages|dependency-groups|optional-dependencies)(\.|$)/) print table "\t" trim($0)
      next
    }
    trim($0) == "" { next }
    in_array { print table "\t" trim($0); if (trim($0) ~ /^\]/) in_array = 0; next }
    table ~ /(^|\.)(dependencies|dev-dependencies|build-dependencies|packages|dev-packages|dependency-groups|optional-dependencies)(\.|$)/ { print table "\t" trim($0); next }
    /^[ \t]*[A-Za-z0-9_-]*dependencies[ \t]*=/ {
      print table "\t" trim($0)
      if ($0 ~ /\[[ \t]*$/ || ($0 ~ /\[/ && $0 !~ /\][ \t]*$/)) in_array = 1
    }
  '
}

pubspec_dependency_view() {
  awk '
    /^[A-Za-z_]+:/ { key = $0; sub(/:.*/, "", key) }
    key ~ /^(dependencies|dev_dependencies|dependency_overrides)$/ {
      line = $0; gsub(/^[ \t]+|[ \t]+$/, "", line)
      if (line != "") print key "\t" line
    }
  '
}

line_dependency_view() {
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -E "$1"
}

dependency_view() {
  case "$base" in
    package.json|composer.json) json_dependency_view ;;
    Cargo.toml|pyproject.toml|Pipfile) toml_dependency_view ;;
    pubspec.yaml) pubspec_dependency_view ;;
    go.mod) line_dependency_view '.' ;;
    Gemfile) line_dependency_view '^gem[[:space:](]' ;;
    Podfile) line_dependency_view '^pod[[:space:](]' ;;
  esac
}

check_cli_manifest() {
  [ -f "$path" ] || deny 'Create it with the scaffolding CLI (bun init, uv init, cargo init, go mod init, flutter create), not by hand.'
  local before after changed
  before=$(dependency_view < "$path" | sort)
  after=$(edited_file_text "$input" "$path" | dependency_view | sort)
  changed=$(comm -3 <(printf '%s\n' "$before") <(printf '%s\n' "$after") \
    | awk '{ mark = sub(/^\t/, "") ? "+ " : "- "; sub(/^[^\t]*\t/, ""); print mark $0 }' \
    | head -5)
  [ -z "$changed" ] && exit 0
  deny "This edit changes dependencies:

$changed

Dependencies go in through the CLI, which resolves the real current version.
Edits outside the dependency sections (scripts, assets, tool settings, the
package's own version) are allowed."
}

remind_manual_manifest() {
  local versions
  versions=$(added_lines "$(old_fragment "$input" "$path")" "$(new_fragment "$input")" | grep -E '[0-9]+\.[0-9]+' | head -3)
  [ -n "$versions" ] || exit 0
  jq -n --arg file "$base" --arg lines "$versions" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: ("craft: this edit to \($file) types a version number:\n\($lines)\nNever type a version from memory. Resolve it from the registry first and say which one you checked.")}}'
  exit 0
}

case "$kind" in
  lock) deny 'A lockfile is only ever written by its package manager.' ;;
  cli) check_cli_manifest ;;
  manual) remind_manual_manifest ;;
esac
exit 0
