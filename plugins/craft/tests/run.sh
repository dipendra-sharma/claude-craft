#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."

fixtures="$PWD/tests/fixtures"
project=/work/app
export CLAUDE_CRAFT_ALLOW_FILE TMPDIR
CLAUDE_CRAFT_ALLOW_FILE=$(mktemp "${TMPDIR:-/tmp}/craft-allow-test.XXXXXX")
TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/craft-test.XXXXXX")
unset CLAUDE_CRAFT_RULES

pass=0
fail=0

report() {
  if [ "$1" = "$2" ]; then
    pass=$((pass + 1))
    printf '  ok   %-58s %s\n' "$3" "$2"
  else
    fail=$((fail + 1))
    printf '  FAIL %-58s want=%s got=%s\n' "$3" "$1" "$2"
  fi
}

expect() {
  printf '%s' "$3" | "./scripts/$2" >/dev/null 2>&1
  report "exit=$1" "exit=$?" "$4"
}

expect_block() {
  local got
  got=$(printf '%s' "$3" | "./scripts/$2" 2>/dev/null | jq -r '.decision // "none"' 2>/dev/null)
  report "$1" "${got:-none}" "$4"
}

bash_cmd() { jq -n --arg c "$1" --arg d "${2:-$fixtures}" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'; }
edit_of() { jq -n --arg p "$1" '{tool_name:"Edit",tool_input:{file_path:$p,old_string:"",new_string:""}}'; }
edit_change() { jq -n --arg p "$1" --arg o "$2" --arg n "$3" '{tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'; }
write_of() { jq -n --arg p "$1" --arg c "$2" '{tool_name:"Write",tool_input:{file_path:$p,content:$c}}'; }

log() { local file; file=$(mktemp); printf '%s\n' "$@" > "$file"; printf '%s' "$file"; }
prompt() { jq -nc --arg id "$1" '{type:"user",uuid:$id,message:{content:"change it"}}'; }
say() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
edits() { jq -nc --arg p "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Edit",input:{file_path:$p}}]}}'; }
runs() { jq -nc --arg c "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}}'; }
result() { jq -nc '{type:"user",message:{content:[{type:"tool_result",content:"ok"}]}}'; }

before_edit() {
  jq -n --arg t "$1" --arg s "$2" --arg p "${3:-$project/src/a.ts}" --arg a "${4:-}" \
    '{session_id:$s,transcript_path:$t,cwd:"/work/app",tool_name:"Edit",tool_input:{file_path:$p}} + (if $a != "" then {agent_id:$a} else {} end)'
}
on_stop() {
  jq -n --arg t "$1" --arg m "${2:-Done.}" --argjson active "${3:-false}" \
    '{transcript_path:$t,cwd:"/work/app",stop_hook_active:$active,last_assistant_message:$m}'
}

echo "plan-proof.sh"
no_plan=$(log "$(prompt u1)" "$(say 'Done when: old turn')" "$(prompt u2)" "$(say 'Editing now.')")
with_plan=$(log "$(prompt u1)" "$(say 'Done when: tests pass — checked by: bun test')")
expect 2 plan-proof.sh "$(before_edit "$no_plan" s1)"                                  'first edit without a plan this turn'
expect 0 plan-proof.sh "$(before_edit "$no_plan" s1)"                                  'asks only once per prompt'
expect 0 plan-proof.sh "$(before_edit "$with_plan" s2)"                                'plan written this turn'
expect 0 plan-proof.sh "$(before_edit "$no_plan" s3 /home/me/.claude/memory/x.md)"      'file outside the project'
expect 0 plan-proof.sh "$(before_edit "$no_plan" s4 "$project/src/a.ts" agent-1)"       'inside a subagent'

echo
echo "verify-before-done.sh"
expect_block block verify-before-done.sh "$(on_stop "$(log "$(prompt u1)" "$(edits $project/src/a.ts)" "$(result)")")" 'edit with no check after it'
expect_block block verify-before-done.sh "$(on_stop "$(log "$(prompt u1)" "$(runs 'bun test')" "$(result)" "$(edits $project/src/a.ts)")")" 'check ran before the edit only'
expect_block none verify-before-done.sh "$(on_stop "$(log "$(prompt u1)" "$(edits $project/src/a.ts)" "$(runs 'bun test src/a.test.ts')")")" 'test ran after the edit'
expect_block none verify-before-done.sh "$(on_stop "$(log "$(prompt u1)" "$(edits $project/bin/deploy.sh)" "$(runs 'bash bin/deploy.sh --dry-run')")")" 'changed script was run'
expect_block none verify-before-done.sh "$(on_stop "$(log "$(prompt u1)" "$(edits $project/README.md)")")" 'documentation only'
expect_block none verify-before-done.sh "$(on_stop "$(log "$(prompt u1)" "$(edits /tmp/scratch.py)")")" 'file outside the project'
expect_block none verify-before-done.sh "$(on_stop "$(log "$(prompt u1)" "$(edits $project/src/a.ts)")" 'This is unverified: no runner here.')" 'says it is unverified'
expect_block none verify-before-done.sh "$(on_stop "$(log "$(prompt u1)" "$(edits $project/src/a.ts)")" 'Done.' true)" 'already nudged once'
expect_block none verify-before-done.sh "$(on_stop "$(log "$(prompt u1)" "$(edits $project/src/a.ts)" "$(runs 'bun test')" "$(prompt u2)" "$(say 'Here is the answer.')")")" 'edit belonged to an earlier turn'

echo
echo "lint-edited-file.sh"
broken=$(mktemp "$TMPDIR/broken.XXXXXX.json")
printf '{"a": 1,,}' > "$broken"
expect_block block lint-edited-file.sh "$(edit_of "$broken")"                          'invalid JSON is reported'
expect_block none lint-edited-file.sh "$(edit_of "$fixtures/package.json")"             'valid JSON passes'
expect_block none lint-edited-file.sh "$(edit_of "$fixtures/Cargo.toml")"               'no linter for the file type'

echo
echo "project-facts.sh"
app=$(mktemp -d "$TMPDIR/app.XXXXXX")
: > "$app/bun.lock"
printf '{"scripts":{"test":"bun test","lint":"biome check"}}' > "$app/package.json"
facts=$(jq -n --arg d "$app" '{cwd:$d}' | ./scripts/project-facts.sh | jq -r '.hookSpecificOutput.additionalContext')
report yes "$(grep -q 'bun (bun.lock)' <<< "$facts" && echo yes || echo no)"           'names the package manager from the lockfile'
report yes "$(grep -q 'scripts: lint, test' <<< "$facts" && echo yes || echo no)"        'lists the package.json scripts'
report yes "$(jq -n --arg d "$PWD" '{cwd:$d}' | ./scripts/project-facts.sh | grep -q 'git: branch' && echo yes || echo no)" 'reports the git branch'

echo
echo "guard-manifest.sh — must BLOCK (exit 2)"
expect 2 guard-manifest.sh "$(edit_of 'bun.lock')"                                         'bun.lock'
expect 2 guard-manifest.sh "$(edit_of 'ios/App.xcworkspace/xcshareddata/swiftpm/Package.resolved')" 'Package.resolved'
expect 2 guard-manifest.sh "$(write_of "$fixtures/new/package.json" '{}')"                 'creating package.json by hand'
expect 2 guard-manifest.sh "$(edit_change "$fixtures/package.json" '"zod": "^3.23.8"' '"zod": "^3.23.8",
    "lodash": "^4.17.21"')"                                                                 'adding a package.json dependency'
expect 2 guard-manifest.sh "$(edit_change "$fixtures/pubspec.yaml" 'http: ^1.2.0' 'http: ^1.2.0
  dio: any')"                                                                               'adding a pubspec dependency'
expect 2 guard-manifest.sh "$(edit_change "$fixtures/Cargo.toml" 'serde = "1"' 'serde = "1"
tokio = "1"')"                                                                              'adding a Cargo dependency'
expect 2 guard-manifest.sh "$(edit_change "$fixtures/pyproject.toml" '"requests>=2.31",' '"requests>=2.31",
    "httpx",')"                                                                             'adding a pyproject dependency'
expect 2 guard-manifest.sh "$(bash_cmd "sed -i '' 's/1.0/2.0/' package.json")"             'sed -i on package.json'
expect 2 guard-manifest.sh "$(bash_cmd 'jq . in.json > bun.lock')"                          'redirect into a lockfile'
expect 2 guard-manifest.sh "$(bash_cmd 'echo x | tee Cargo.lock')"                          'tee into a lockfile'
expect 2 guard-manifest.sh "$(bash_cmd 'cat > pubspec.yaml <<EOF
name: x
EOF')"                                                                                      'heredoc into pubspec.yaml'

echo
echo "guard-manifest.sh — must ALLOW (exit 0)"
expect 0 guard-manifest.sh "$(edit_change "$fixtures/package.json" '"build": "tsc"' '"build": "tsc -p ."')" 'package.json script'
expect 0 guard-manifest.sh "$(edit_change "$fixtures/pubspec.yaml" 'version: 1.0.0+1' 'version: 1.0.1+2')" 'pubspec app version'
expect 0 guard-manifest.sh "$(edit_change "$fixtures/Cargo.toml" 'default = []' 'default = ["std"]')" 'Cargo features'
expect 0 guard-manifest.sh "$(edit_change "$fixtures/pyproject.toml" 'line-length = 100' 'line-length = 120')" 'pyproject tool settings'
expect 0 guard-manifest.sh "$(edit_of 'src/main.ts')"                                      'source file'
expect 0 guard-manifest.sh "$(bash_cmd 'jq .name package.json > name.txt')"               'reading a manifest into another file'
expect 0 guard-manifest.sh "$(bash_cmd 'bun add zod')"                                     'dependency via the command line'
expect 0 guard-manifest.sh "$(bash_cmd 'CLAUDE_CRAFT_RULES=off sed -i "" s/a/b/ bun.lock')" 'escape hatch prefix'
./bin/craft-allow "$PWD/bun.lock" >/dev/null
expect 0 guard-manifest.sh "$(edit_of "$PWD/bun.lock")"                                    'lockfile after craft-allow'

echo
echo "git-format.sh — must BLOCK (exit 2)"
expect 2 git-format.sh "$(bash_cmd 'git checkout -b my-feature')"                          'branch without a type'
expect 2 git-format.sh "$(bash_cmd 'git switch -c Feat/Login')"                            'branch with capitals'
expect 2 git-format.sh "$(bash_cmd 'git branch fix/login_page')"                           'branch with an underscore'
expect 2 git-format.sh "$(bash_cmd 'git checkout -b feat/this-branch-name-is-far-too-long-to-read-in-one-go')" 'branch over 50 characters'
expect 2 git-format.sh "$(bash_cmd 'git branch -m old wip')"                               'renaming to a bad name'
expect 2 git-format.sh "$(bash_cmd 'git commit -m "updated stuff"')"                       'commit without a type'
expect 2 git-format.sh "$(bash_cmd 'git add . && git commit -am "Fix: login"')"            'commit with a capitalised type'
expect 2 git-format.sh "$(bash_cmd "git commit -m \"\$(cat <<'EOF'
added the thing

Ref: https://example.com/1
EOF
)\"")"                                                                                      'bad subject inside a heredoc'
expect 2 git-format.sh "$(bash_cmd 'gh pr create --title "Login fixes" --body "x"')"        'pull request title without a type'

echo
echo "git-format.sh — must ALLOW (exit 0)"
expect 0 git-format.sh "$(bash_cmd 'git checkout -b feat/auth-refresh-token')"             'good branch name'
expect 0 git-format.sh "$(bash_cmd 'git switch -c fix/login origin/main')"                 'good branch with a start point'
expect 0 git-format.sh "$(bash_cmd 'git checkout main && git branch -d old_branch')"        'deleting a branch'
expect 0 git-format.sh "$(bash_cmd 'git branch --show-current')"                           'reading the branch'
expect 0 git-format.sh "$(bash_cmd 'git commit -m "fix(auth): refresh the token early"')"   'good commit subject'
expect 0 git-format.sh "$(bash_cmd 'git commit -m "docs: explain the hooks"')"              'subject without a scope'
expect 0 git-format.sh "$(bash_cmd "git commit -m \"\$(cat <<'EOF'
feat(hooks): add the git format hook

Co-Authored-By: Someone <someone@example.com>
EOF
)\"")"                                                                                      'good subject inside a heredoc'
expect 0 git-format.sh "$(bash_cmd 'git commit --amend --no-edit')"                        'amend without a message'
expect 0 git-format.sh "$(bash_cmd 'git commit -m "Merge branch main into feat/x"')"        'merge commit'
expect 0 git-format.sh "$(bash_cmd 'gh pr create --title "feat(auth): refresh tokens" --body "x"')" 'good pull request title'
expect 0 git-format.sh "$(bash_cmd 'gh pr view 12')"                                       'reading a pull request'
expect 0 git-format.sh "$(bash_cmd 'CLAUDE_CRAFT_RULES=off git commit -m "wip"')"           'escape hatch prefix'

echo
printf 'passed %s, failed %s\n' "$pass" "$fail"
[ "$fail" = 0 ]
