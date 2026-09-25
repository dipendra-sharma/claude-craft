#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
cd "$(jq -r '.cwd // "."' <<< "$input")" 2>/dev/null || exit 0

facts=()
fact() { facts+=("- $1"); }
first_line() { "$@" 2>&1 | head -n 1; }

if branch=$(git branch --show-current 2>/dev/null); then
  fact "git: branch ${branch:-(detached)}, $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') changed files"
fi

managers=""
for pair in bun.lock:bun bun.lockb:bun pnpm-lock.yaml:pnpm yarn.lock:yarn package-lock.json:npm \
  uv.lock:uv poetry.lock:poetry Pipfile.lock:pipenv Cargo.lock:cargo go.mod:go pubspec.lock:dart/flutter \
  Gemfile.lock:bundler composer.lock:composer Podfile.lock:pod gradlew:gradle mvnw:maven; do
  [ -e "${pair%%:*}" ] && managers+="${pair#*:} (${pair%%:*}), "
done
[ -n "$managers" ] && fact "package managers, from lockfiles: ${managers%, }"

[ -f package.json ] && scripts=$(jq -r '.scripts // {} | keys | join(", ")' package.json 2>/dev/null) && [ -n "$scripts" ] \
  && fact "package.json scripts: $scripts"
[ -f Makefile ] && targets=$(grep -oE '^[A-Za-z0-9_.-]+:' Makefile | tr -d : | head -n 15 | paste -sd, - | sed 's/,/, /g') \
  && [ -n "$targets" ] && fact "make targets: $targets"

for pin in .nvmrc .node-version .python-version .ruby-version .java-version .tool-versions rust-toolchain rust-toolchain.toml; do
  [ -f "$pin" ] && fact "pinned in $pin: $(tr '\n' ' ' < "$pin" | sed 's/ *$//')"
done
[ -f go.mod ] && fact "go.mod: $(grep -m1 -E '^go ' go.mod)"

installed=()
[ -f package.json ] && command -v node >/dev/null && installed+=("node $(first_line node --version)")
[[ "$managers" == *bun* ]] && installed+=("bun $(first_line bun --version)")
[ -f pyproject.toml ] && command -v python3 >/dev/null && installed+=("$(first_line python3 --version)")
[[ "$managers" == *uv* ]] && installed+=("$(first_line uv --version)")
[ -f go.mod ] && command -v go >/dev/null && installed+=("$(first_line go version)")
[ -f Cargo.toml ] && command -v cargo >/dev/null && installed+=("$(first_line cargo --version)")
[ -f pubspec.yaml ] && command -v dart >/dev/null && installed+=("$(first_line dart --version)")
[ ${#installed[@]} -gt 0 ] && fact "installed: $(IFS=';'; printf '%s' "${installed[*]}" | sed 's/;/; /g')"

[ ${#facts[@]} -gt 0 ] || exit 0
jq -n --arg facts "$(printf '%s\n' "${facts[@]}")" '{hookSpecificOutput: {hookEventName: "SessionStart",
  additionalContext: ("Project facts read from disk at session start by the craft plugin. Trust these over memory, and use the tools they name:\n" + $facts)}}'
