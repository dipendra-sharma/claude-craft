#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."

pass=0
fail=0

expect() {
  local want="$1" script="$2" json="$3" label="$4"
  printf '%s' "$json" | "./scripts/$script" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
    printf '  ok   %-58s exit=%s\n' "$label" "$got"
  else
    fail=$((fail + 1))
    printf '  FAIL %-58s want=%s got=%s\n' "$label" "$want" "$got"
  fi
}

bash_cmd() { jq -n --arg c "$1" '{tool_name:"Bash",cwd:".",tool_input:{command:$c}}'; }
edit_of() { jq -n --arg p "$1" '{tool_name:"Edit",cwd:".",tool_input:{file_path:$p}}'; }

echo "guard-bash.sh — must BLOCK (exit 2)"
expect 2 guard-bash.sh "$(bash_cmd 'rm -rf /Users/dipendra-sharma/notes')"                 'rm on a real path'
expect 2 guard-bash.sh "$(bash_cmd 'rm important.txt')"                                    'rm a single file'
expect 2 guard-bash.sh "$(bash_cmd 'python -c "import shutil; shutil.rmtree(p)"')"         'shutil.rmtree'
expect 2 guard-bash.sh "$(bash_cmd 'git commit -m "fix: x

Co-Authored-By: Claude <noreply@anthropic.com>"')"                                         'attribution trailer in commit'
expect 2 guard-bash.sh "$(bash_cmd 'gh pr create --body "Generated with Claude Code"')"     'attribution in pull request body'
expect 2 guard-bash.sh "$(bash_cmd 'git push --force origin main')"                        'git push --force'
expect 2 guard-bash.sh "$(bash_cmd 'git clone git@github.com:acme/app.git')"               'SSH remote'
expect 2 guard-bash.sh "$(bash_cmd 'git rm stale.txt')"                                    'git rm without --cached'
expect 2 guard-bash.sh "$(bash_cmd 'sleep 5 && curl localhost:8080')"                      'sleep'
expect 2 guard-bash.sh "$(bash_cmd './gradlew clean build test')"                          'three Gradle tasks at once'
expect 2 guard-bash.sh "$(bash_cmd './gradlew assembleDebug --no-daemon')"                 'Gradle tuning flag'

echo
echo "guard-bash.sh — must ALLOW (exit 0)"
expect 0 guard-bash.sh "$(bash_cmd 'trash notes.txt')"                                     'trash'
expect 0 guard-bash.sh "$(bash_cmd 'rm -rf node_modules')"                                 'rm a cache folder'
expect 0 guard-bash.sh "$(bash_cmd 'rm -rf build/ .gradle/')"                              'rm build output'
expect 0 guard-bash.sh "$(bash_cmd 'git commit -m "feat(auth): add refresh"')"             'clean commit'
expect 0 guard-bash.sh "$(bash_cmd 'git push --force-with-lease origin main')"             'force-with-lease'
expect 0 guard-bash.sh "$(bash_cmd 'git clone https://github.com/acme/app.git')"           'HTTPS remote'
expect 0 guard-bash.sh "$(bash_cmd 'git rm --cached secret.env')"                          'git rm --cached'
expect 0 guard-bash.sh "$(bash_cmd 'timeout 60 ./run-server.sh')"                          'timeout instead of sleep'
expect 0 guard-bash.sh "$(bash_cmd './gradlew assembleDebug')"                             'one Gradle task'
expect 0 guard-bash.sh "$(bash_cmd 'npm ci && echo confirm')"                              'words containing rm'
expect 0 guard-bash.sh "$(bash_cmd 'bun add zod')"                                         'dependency via CLI'

echo
echo "guard-write.sh — must BLOCK (exit 2)"
expect 2 guard-write.sh "$(edit_of 'app/package.json')"                                    'package.json'
expect 2 guard-write.sh "$(edit_of 'bun.lock')"                                            'bun.lock'
expect 2 guard-write.sh "$(edit_of 'pubspec.yaml')"                                        'pubspec.yaml'
expect 2 guard-write.sh "$(edit_of 'Cargo.toml')"                                          'Cargo.toml'
expect 2 guard-write.sh "$(edit_of 'app/build.gradle.kts')"                                'build.gradle.kts'
expect 2 guard-write.sh "$(edit_of 'go.sum')"                                              'go.sum'

echo
echo "guard-write.sh — must ALLOW (exit 0)"
expect 0 guard-write.sh "$(edit_of 'src/main.ts')"                                         'source file'
expect 0 guard-write.sh "$(edit_of 'README.md')"                                           'documentation'
expect 0 guard-write.sh "$(edit_of 'lib/widgets/home_page.dart')"                          'Dart source'

echo
printf 'passed %s, failed %s\n' "$pass" "$fail"
[ "$fail" = 0 ]
