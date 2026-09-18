#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."

fixtures="$PWD/tests/fixtures"
export CRAFT_PROCESS_LIST_FILE="$fixtures/ps-idle.txt"
export CLAUDE_CRAFT_ALLOW_FILE
CLAUDE_CRAFT_ALLOW_FILE=$(mktemp "${TMPDIR:-/tmp}/craft-allow-test.XXXXXX")
unset CLAUDE_CRAFT_RULES

pass=0
fail=0

expect() {
  local want="$1" script="$2" json="$3" label="$4"
  printf '%s' "$json" | "./scripts/$script" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
    printf '  ok   %-62s exit=%s\n' "$label" "$got"
  else
    fail=$((fail + 1))
    printf '  FAIL %-62s want=%s got=%s\n' "$label" "$want" "$got"
  fi
}

expect_busy() {
  CRAFT_PROCESS_LIST_FILE="$fixtures/ps-busy.txt" expect "$@"
}

expect_context() {
  local label="$2"
  if printf '%s' "$1" | ./scripts/guard-write.sh 2>/dev/null | jq -e '.hookSpecificOutput.additionalContext | length > 0' >/dev/null; then
    pass=$((pass + 1))
    printf '  ok   %-62s reminder\n' "$label"
  else
    fail=$((fail + 1))
    printf '  FAIL %-62s no reminder\n' "$label"
  fi
}

bash_cmd() { jq -n --arg c "$1" --arg d "${2:-$fixtures}" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'; }
edit_of() { jq -n --arg p "$1" '{tool_name:"Edit",tool_input:{file_path:$p,old_string:"",new_string:""}}'; }
edit_change() { jq -n --arg p "$1" --arg o "$2" --arg n "$3" '{tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'; }
write_of() { jq -n --arg p "$1" --arg c "$2" '{tool_name:"Write",tool_input:{file_path:$p,content:$c}}'; }
slack_send() { jq -n '{tool_name:"mcp__claude_ai_Slack__slack_send_message",tool_input:{}}'; }

echo "guard-bash.sh — must BLOCK (exit 2)"
expect 2 guard-bash.sh "$(bash_cmd 'rm -rf /Users/dipendra-sharma/notes')"                    'rm on a real path'
expect 2 guard-bash.sh "$(bash_cmd 'rm important.txt')"                                       'rm a single file'
expect 2 guard-bash.sh "$(bash_cmd 'rm -rf ~/Documents/taxes /tmp/scratch')"                  'one real path among cache paths'
expect 2 guard-bash.sh "$(bash_cmd 'rm -rf ~/.ssh && ls node_modules')"                       'cache path in a different segment'
expect 2 guard-bash.sh "$(bash_cmd 'cd /tmp && rm -rf ~/Documents')"                          'cache path before the rm'
expect 2 guard-bash.sh "$(bash_cmd '/bin/rm -rf src')"                                        'rm by full path'
expect 2 guard-bash.sh "$(bash_cmd '\rm -rf src')"                                            'rm with a leading backslash'
expect 2 guard-bash.sh "$(bash_cmd 'command rm -rf src')"                                     'rm through command'
expect 2 guard-bash.sh "$(bash_cmd 'sudo rm -rf src')"                                        'rm through sudo'
expect 2 guard-bash.sh "$(bash_cmd '(rm -rf src)')"                                           'rm in a subshell'
expect 2 guard-bash.sh "$(bash_cmd 'if true; then rm -rf src; fi')"                           'rm inside if/then'
expect 2 guard-bash.sh "$(bash_cmd 'echo "$(rm -rf src)"')"                                   'rm inside command substitution'
expect 2 guard-bash.sh "$(bash_cmd 'bash -c "rm -rf src"')"                                   'rm inside bash -c'
expect 2 guard-bash.sh "$(bash_cmd 'ls | xargs rm')"                                          'rm through xargs'
expect 2 guard-bash.sh "$(bash_cmd 'unlink notes.txt')"                                       'unlink'
expect 2 guard-bash.sh "$(bash_cmd 'find . -name "*.kt" -delete')"                            'find -delete on real files'
expect 2 guard-bash.sh "$(bash_cmd 'find src -exec rm {} +')"                                 'find -exec rm'
expect 2 guard-bash.sh "$(bash_cmd 'git clean -fdx')"                                         'git clean -f'
expect 2 guard-bash.sh "$(bash_cmd 'rm -rf build/../../src')"                                 'climbing out of a build folder'
expect 2 guard-bash.sh "$(bash_cmd 'rm -rf /tmp/../Users/me/notes')"                          'climbing out of /tmp'
expect 2 guard-bash.sh "$(bash_cmd 'python -c "import shutil; shutil.rmtree(p)"')"            'shutil.rmtree'
expect 2 guard-bash.sh "$(bash_cmd 'git commit -m "fix: x

Co-Authored-By: Claude <noreply@anthropic.com>"')"                                            'attribution trailer in commit'
expect 2 guard-bash.sh "$(bash_cmd 'gh pr create --body "Generated with Claude Code"')"       'attribution in pull request body'
expect 2 guard-bash.sh "$(bash_cmd 'git commit -F attributed-message.txt')"                   'attribution in a commit message file'
expect 2 guard-bash.sh "$(bash_cmd 'gh pr create --body-file attributed-message.txt')"        'attribution in a pull request body file'
expect 2 guard-bash.sh "$(bash_cmd 'gh pr comment 1 --body "🤖 Generated with [Claude Code](https://claude.com/claude-code)"')" 'attribution in a pull request comment'
expect 2 guard-bash.sh "$(bash_cmd 'git push --force origin main')"                           'git push --force'
expect 2 guard-bash.sh "$(bash_cmd 'git push -uf origin main')"                               'git push with combined -f'
expect 2 guard-bash.sh "$(bash_cmd 'git push origin +main')"                                  'git push with a + refspec'
expect 2 guard-bash.sh "$(bash_cmd 'git -C app push --force')"                                'git -C before push --force'
expect 2 guard-bash.sh "$(bash_cmd 'git clone git@github.com:acme/app.git')"                  'SSH remote'
expect 2 guard-bash.sh "$(bash_cmd 'git clone ssh://git@github.com/acme/app.git')"            'ssh:// remote'
expect 2 guard-bash.sh "$(bash_cmd 'git rm stale.txt')"                                       'git rm without --cached'
expect 2 guard-bash.sh "$(bash_cmd 'git rm --cached a.txt && git rm b.txt')"                  'second git rm without --cached'
expect 2 guard-bash.sh "$(bash_cmd 'git worktree add ../wt' /)"                               'worktree outside a repository'
expect 2 guard-bash.sh "$(bash_cmd 'sleep 5 && curl localhost:8080')"                         'sleep'
expect 2 guard-bash.sh "$(bash_cmd 'while ! curl -s localhost; do sleep 1; done')"            'sleep inside a polling loop'
expect 2 guard-bash.sh "$(bash_cmd 'sleep $DELAY')"                                           'sleep on a variable'
expect 2 guard-bash.sh "$(bash_cmd "sed -i '' 's/1.0/2.0/' package.json")"                    'sed -i on package.json'
expect 2 guard-bash.sh "$(bash_cmd 'cat > pubspec.yaml <<EOF
name: x
EOF')"                                                                                        'heredoc into pubspec.yaml'
expect 2 guard-bash.sh "$(bash_cmd 'jq . in.json > bun.lock')"                                'redirect into a lockfile'
expect 2 guard-bash.sh "$(bash_cmd 'echo x | tee Cargo.lock')"                                'tee into a lockfile'
expect 2 guard-bash.sh "$(bash_cmd './gradlew clean build test')"                             'three Gradle tasks at once'
expect 2 guard-bash.sh "$(bash_cmd './gradlew assembleDebug --no-daemon')"                    'Gradle tuning flag'
expect_busy 2 guard-bash.sh "$(bash_cmd './gradlew assembleDebug')"                           'Gradle while another build runs'
expect_busy 2 guard-bash.sh "$(bash_cmd 'xcodebuild -scheme App build')"                      'xcodebuild while another build runs'

echo
echo "guard-bash.sh — must ALLOW (exit 0)"
expect 0 guard-bash.sh "$(bash_cmd 'trash notes.txt')"                                        'trash'
expect 0 guard-bash.sh "$(bash_cmd 'rm -rf node_modules')"                                    'rm a cache folder'
expect 0 guard-bash.sh "$(bash_cmd 'rm -rf build/ .gradle/')"                                 'rm build output'
expect 0 guard-bash.sh "$(bash_cmd 'rm -rf build/ dist/ node_modules/')"                      'several cache paths'
expect 0 guard-bash.sh "$(bash_cmd 'rm -rf build 2>/dev/null')"                               'rm a cache folder with a redirect'
expect 0 guard-bash.sh "$(bash_cmd 'rm -rf "$TMPDIR/scratch"')"                               'rm a quoted temp path'
expect 0 guard-bash.sh "$(bash_cmd 'find build -name "*.o" -delete')"                         'find -delete inside a build folder'
expect 0 guard-bash.sh "$(bash_cmd 'git clean -n')"                                           'git clean dry run'
expect 0 guard-bash.sh "$(bash_cmd 'command -v rm')"                                          'looking up rm'
expect 0 guard-bash.sh "$(bash_cmd 'npm ci && echo confirm')"                                 'words containing rm'
expect 0 guard-bash.sh "$(bash_cmd 'git commit -m "feat(auth): add refresh"')"                'clean commit'
expect 0 guard-bash.sh "$(bash_cmd 'git commit -F clean-message.txt')"                        'clean commit message file'
expect 0 guard-bash.sh "$(bash_cmd 'git commit -m "docs: never rm -rf; sleep 5 is banned"')"  'rule words inside a quoted message'
expect 0 guard-bash.sh "$(bash_cmd 'git commit -F - <<EOF
docs: explain the guard

rm -rf src && sleep 5
EOF')"                                                                                        'rule words inside a heredoc message'
expect 0 guard-bash.sh "$(bash_cmd 'git push --force-with-lease origin main')"                'force-with-lease'
expect 0 guard-bash.sh "$(bash_cmd 'git push origin main && rm -f build/x.o')"                '-f belonging to a later rm'
expect 0 guard-bash.sh "$(bash_cmd 'git push && npm install --force')"                        '--force belonging to a later npm'
expect 0 guard-bash.sh "$(bash_cmd 'git clone https://github.com/acme/app.git')"              'HTTPS remote'
expect 0 guard-bash.sh "$(bash_cmd 'git rm --cached secret.env')"                             'git rm --cached'
expect 0 guard-bash.sh "$(bash_cmd 'git worktree add ../wt')"                                 'worktree inside a repository'
expect 0 guard-bash.sh "$(bash_cmd 'timeout 60 ./run-server.sh')"                             'timeout instead of sleep'
expect 0 guard-bash.sh "$(bash_cmd 'git log --oneline | grep -c "sleep 5"')"                  'sleep as a search word'
expect 0 guard-bash.sh "$(bash_cmd 'CLAUDE_CRAFT_RULES=off git push --force')"                'escape hatch prefix'
expect 0 guard-bash.sh "$(bash_cmd 'CLAUDE_CRAFT_RULES=off sleep 5')"                         'escape hatch prefix on sleep'
expect 0 guard-bash.sh "$(bash_cmd 'jq .name package.json')"                                  'reading a manifest'
expect 0 guard-bash.sh "$(bash_cmd "sed -i '' 's/a/b/' app/build.gradle.kts")"                'shell edit of a Gradle file'
expect 0 guard-bash.sh "$(bash_cmd 'bun add zod')"                                            'dependency via CLI'
expect 0 guard-bash.sh "$(bash_cmd './gradlew assembleDebug')"                                'one Gradle task'
expect 0 guard-bash.sh "$(bash_cmd './gradlew assembleDebug 2>&1 | tee build.log')"           'one task, piped to a log'
expect 0 guard-bash.sh "$(bash_cmd './gradlew assembleDebug > out.txt')"                      'one task, redirected'
expect 0 guard-bash.sh "$(bash_cmd './gradlew :app:assembleDebug --stacktrace')"              'qualified task with a flag'
expect 0 guard-bash.sh "$(bash_cmd './gradlew test --tests com.acme.FooTest')"                'one task with --tests'
expect 0 guard-bash.sh "$(bash_cmd './gradlew -p app assembleDebug')"                         'one task with -p'
expect 0 guard-bash.sh "$(bash_cmd './gradlew assembleDebug -x lint')"                        'one task with -x'
expect 0 guard-bash.sh "$(bash_cmd 'gradle build')"                                           'plain gradle, one task'
expect 0 guard-bash.sh "$(bash_cmd 'cd android && ./gradlew assembleDebug')"                  'Gradle after cd'
expect_busy 0 guard-bash.sh "$(bash_cmd 'cat gradlew')"                                       'reading gradlew while a build runs'

echo
echo "guard-write.sh — must BLOCK (exit 2)"
expect 2 guard-write.sh "$(edit_of 'bun.lock')"                                               'bun.lock'
expect 2 guard-write.sh "$(edit_of 'go.sum')"                                                 'go.sum'
expect 2 guard-write.sh "$(edit_of 'ios/App.xcworkspace/xcshareddata/swiftpm/Package.resolved')" 'Package.resolved'
expect 2 guard-write.sh "$(write_of "$fixtures/new/package.json" '{}')"                       'creating package.json by hand'
expect 2 guard-write.sh "$(edit_change "$fixtures/package.json" '"zod": "^3.23.8"' '"zod": "^3.23.8",
    "lodash": "^4.17.21"')"                                                                   'adding a package.json dependency'
expect 2 guard-write.sh "$(edit_change "$fixtures/pubspec.yaml" 'http: ^1.2.0' 'http: ^1.2.0
  dio: any')"                                                                                 'adding a pubspec dependency'
expect 2 guard-write.sh "$(edit_change "$fixtures/Cargo.toml" 'serde = "1"' 'serde = "1"
tokio = "1"')"                                                                                'adding a Cargo dependency'
expect 2 guard-write.sh "$(edit_change "$fixtures/pyproject.toml" '"requests>=2.31",' '"requests>=2.31",
    "httpx",')"                                                                               'adding a pyproject dependency'

echo
echo "guard-write.sh — must ALLOW (exit 0)"
expect 0 guard-write.sh "$(edit_change "$fixtures/package.json" '"build": "tsc"' '"build": "tsc -p ."')" 'package.json script'
expect 0 guard-write.sh "$(edit_change "$fixtures/pubspec.yaml" '    - assets/' '    - assets/
    - fonts/')"                                                                               'pubspec assets'
expect 0 guard-write.sh "$(edit_change "$fixtures/pubspec.yaml" 'version: 1.0.0+1' 'version: 1.0.1+2')" 'pubspec app version'
expect 0 guard-write.sh "$(edit_change "$fixtures/Cargo.toml" 'default = []' 'default = ["std"]')" 'Cargo features'
expect 0 guard-write.sh "$(edit_change "$fixtures/pyproject.toml" 'line-length = 100' 'line-length = 120')" 'pyproject tool settings'
expect 0 guard-write.sh "$(edit_change 'app/build.gradle.kts' 'minSdk = 24' 'minSdk = 26')"   'Gradle config'
expect 0 guard-write.sh "$(edit_of 'src/main.ts')"                                            'source file'
expect 0 guard-write.sh "$(edit_of 'README.md')"                                              'documentation'
expect_context "$(edit_change 'app/build.gradle.kts' 'implementation(libs.core)' 'implementation("androidx.core:core-ktx:1.13.1")')" 'Gradle version literal gets a reminder'
./bin/craft-allow bun.lock >/dev/null
expect 0 guard-write.sh "$(edit_of "$PWD/bun.lock")"                                          'lockfile after craft-allow'

echo
echo "check-comments.sh — must BLOCK (exit 2)"
expect 2 check-comments.sh "$(edit_change "$fixtures/commented.py" 'total = 1' '# add one
total = 1')"                                                                                  'new Python comment'
expect 2 check-comments.sh "$(edit_change 'src/a.ts' 'const x = 1' 'const x = 1 // note')"    'trailing TypeScript comment'
expect 2 check-comments.sh "$(edit_change 'src/A.kt' 'val x = 1' '/* note */
val x = 1')"                                                                                  'Kotlin block comment'
expect 2 check-comments.sh "$(edit_change 'src/a.py' 'def f():' 'def f():
    """Return nothing."""')"                                                                  'Python docstring'
expect 2 check-comments.sh "$(write_of "$fixtures/new/thing.py" '# note
x = 1')"                                                                                      'comment in a brand new file'

echo
echo "check-comments.sh — must ALLOW (exit 0)"
expect 0 check-comments.sh "$(edit_change "$fixtures/commented.py" '# an existing note
total = 1' '# an existing note
total = 2')"                                                                                  'existing comment left alone'
expect 0 check-comments.sh "$(write_of "$fixtures/commented.py" '# an existing note
total = 2')"                                                                                  'rewrite keeping an existing comment'
expect 0 check-comments.sh "$(edit_change 'src/a.rs' 'struct S;' '#[derive(Debug)]
struct S;')"                                                                                  'Rust attribute'
expect 0 check-comments.sh "$(edit_change 'src/a.c' '' '#include <stdio.h>')"                 'C include'
expect 0 check-comments.sh "$(edit_change 'src/A.kt' 'val x = 1' 'val s = """
  hi
"""')"                                                                                        'Kotlin raw string'
expect 0 check-comments.sh "$(edit_change 'src/a.ts' 'const u = 1' 'const u = "https://example.com"')" 'URL in a string'
expect 0 check-comments.sh "$(edit_change 'src/a.py' 'x = f()' 'x = f()  # noqa: E501')"     'lint pragma'
expect 0 check-comments.sh "$(edit_change 'src/a.ts' 'log()' '// eslint-disable-next-line no-console
log()')"                                                                                      'eslint pragma'
expect 0 check-comments.sh "$(edit_change 'run.sh' 'echo $a' '# shellcheck disable=SC2086
echo $a')"                                                                                    'shellcheck pragma'
expect 0 check-comments.sh "$(edit_change 'README.md' 'x' '# Heading')"                       'markdown heading'

echo
echo "guard-slack.sh"
expect 2 guard-slack.sh "$(slack_send)"                                                       'direct Slack send is blocked'
./bin/craft-allow slack >/dev/null
expect 0 guard-slack.sh "$(slack_send)"                                                       'one send allowed after craft-allow slack'
expect 2 guard-slack.sh "$(slack_send)"                                                       'the allowance is used up'

echo
printf 'passed %s, failed %s\n' "$pass" "$fail"
[ "$fail" = 0 ]
