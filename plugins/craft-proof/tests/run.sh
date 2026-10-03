#!/bin/bash
set -uo pipefail
unset CLAUDE_CRAFT_RULES CLAUDE_PROJECT_DIR

PLUGIN_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPTS="${PROOF_SCRIPTS:-$PLUGIN_ROOT/scripts}"
WORK_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/proof-tests.XXXXXX")
export CLAUDE_CONFIG_DIR="$WORK_ROOT/config"
JQ=$(command -v jq)
passed=0
failed=0
failures=""

new_fixture() {
  local dir="$WORK_ROOT/$1"
  mkdir -p "$dir/tests"
  printf 'def total(prices, coupon=0):\n    return sum(prices) - coupon\n' > "$dir/cart.py"
  cat > "$dir/tests/test_cart.py" <<'EOF'
import unittest
from cart import total


class TotalTest(unittest.TestCase):
    def test_sums_prices(self):
        self.assertEqual(total([3, 4]), 7)

    def test_subtracts_small_coupon(self):
        self.assertEqual(total([10], coupon=4), 6)


if __name__ == "__main__":
    unittest.main()
EOF
  printf '#!/bin/bash\ncd "$(dirname "$0")" && PYTHONPATH=. /usr/bin/python3 -m unittest discover -s tests 2>&1\n' > "$dir/run-tests.sh"
  chmod +x "$dir/run-tests.sh"
  printf '# Cart\n' > "$dir/README.md"
  git -C "$dir" init -q
  git -C "$dir" add -A
  git -C "$dir" -c user.name=fixture -c user.email=fixture@example.invalid commit -qm init
  printf '%s' "$dir"
}

state_of() {
  printf '%s/craft-proof/%s' "$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)" "$(printf '%s' "$(cd "$1" && pwd -P)" | shasum -a 256 | cut -c1-16)"
}

hook() {
  local script=$1 payload=$2
  shift 2
  printf '%s' "$payload" | /bin/bash "$SCRIPTS/$script" "$@" 2>/dev/null
}

start_session() {
  hook proof-session-start.sh "$("$JQ" -nc --arg cwd "$1" --arg s "${2:-startup}" '{hook_event_name: "SessionStart", source: $s, cwd: $cwd}')" > /dev/null
}

edit_payload() {
  "$JQ" -nc --arg cwd "$1" --arg tool "$2" --arg path "$3" --arg text "$4" \
    '{hook_event_name: "PreToolUse", tool_name: $tool, cwd: $cwd, tool_input: (if $tool == "Write" then {file_path: $path, content: $text} else {file_path: $path, old_string: "x", new_string: $text} end)}'
}

replace_payload() {
  "$JQ" -nc --arg cwd "$1" --arg path "$2" --arg old "$3" --arg new "$4" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $path, old_string: $old, new_string: $new}}'
}

multi_edit_payload() {
  "$JQ" -nc --arg cwd "$1" --arg path "$2" --arg old "$3" --arg new "$4" \
    '{hook_event_name: "PreToolUse", tool_name: "MultiEdit", cwd: $cwd, tool_input: {file_path: $path, edits: [{old_string: $old, new_string: $new}]}}'
}

bash_payload() {
  "$JQ" -nc --arg cwd "$1" --arg cmd "$2" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $cwd, tool_input: {command: $cmd}}'
}

result_payload() {
  local cwd=$1 cmd=$2 code=$3 background=${4:-false}
  if [ "$code" = 0 ]; then
    "$JQ" -nc --arg cwd "$cwd" --arg cmd "$cmd" --argjson bg "$background" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_use_id: "toolu_test", cwd: $cwd, tool_input: {command: $cmd, run_in_background: $bg}, tool_response: {stdout: "ok", stderr: "", interrupted: false, isImage: false}}'
  else
    "$JQ" -nc --arg cwd "$cwd" --arg cmd "$cmd" --arg code "$code" '{hook_event_name: "PostToolUseFailure", tool_name: "Bash", tool_use_id: "toolu_test", cwd: $cwd, tool_input: {command: $cmd}, error: ("Exit code " + $code + "\nfailed")}'
  fi
}

stop_payload() {
  "$JQ" -nc --arg cwd "$1" --argjson active "${2:-false}" --arg msg "${3:-Done.}" \
    '{hook_event_name: "Stop", cwd: $cwd, stop_hook_active: $active, last_assistant_message: $msg}'
}

write_contract() {
  mkdir -p "$1/.proof"
  printf '%s' "$2" > "$1/.proof/contract.json"
  hook proof-after-edit.sh "$(edit_payload "$1" Write "$1/.proof/contract.json" "")" > /dev/null
}

run_check() {
  local dir=$1 check=$2 code
  hook proof-guard-bash.sh "$(bash_payload "$dir" "$check")" > /dev/null
  (cd "$dir" && eval "$check" > /dev/null 2>&1)
  code=$?
  hook proof-record-evidence.sh "$(result_payload "$dir" "$check" "$code")" "$([ "$code" = 0 ] && printf pass || printf fail)" > /dev/null
  [ "$code" = 0 ] && printf pass || printf fail
}

evidence_count() {
  local file; file="$(state_of "$1")/evidence.jsonl"
  [ -f "$file" ] || { printf 0; return; }
  "$JQ" -s --arg r "${2:-}" 'map(select($r == "" or .result == $r)) | length' "$file"
}

decision_of() {
  [ -n "$1" ] || { printf allow; return; }
  printf '%s' "$1" | "$JQ" -r '.hookSpecificOutput.permissionDecision // .decision // "allow"' 2>/dev/null || printf allow
}

expect_decision() {
  local name=$1 expected=$2 actual
  actual=$(decision_of "$3")
  if [ "$actual" = "$expected" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    failures="$failures
FAIL $name: expected $expected, got $actual
$3"
  fi
}

expect_equal() {
  if [ "$2" = "$3" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    failures="$failures
FAIL $1: expected [$2], got [$3]"
  fi
}

BUGFIX_CONTRACT='{"goal":"Total never goes below zero","kind":"bugfix","claims":[{"id":"C1","claim":"A coupon larger than the cart gives 0","check":"./run-tests.sh","fail_first":true}]}'
CHANGE_CONTRACT='{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}'
NEW_TEST='import unittest
from cart import total


class OversizedCouponTest(unittest.TestCase):
    def test_total_is_zero_when_coupon_exceeds_cart(self):
        self.assertEqual(total([5], coupon=9), 0)
'
FIXED_CART='def total(prices, coupon=0):
    return max(0, sum(prices) - coupon)
'

test_session_start_keeps_state_out_of_the_work_tree() {
  local dir; dir=$(new_fixture session-start)
  start_session "$dir"
  expect_equal baseline_lists_existing_test 1 "$(cut -f2 "$(state_of "$dir")/baseline.tsv" | grep -c '^tests/test_cart.py$')"
  expect_equal nothing_new_in_git_status "" "$(git -C "$dir" status --porcelain)"
}

test_code_and_deliverable_edits_need_a_contract_but_claude_settings_do_not() {
  local dir; dir=$(new_fixture no-contract)
  start_session "$dir"
  expect_decision code_edit_without_contract_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/cart.py" x)")"
  expect_decision doc_edit_without_contract_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/README.md" x)")"
  expect_decision claude_settings_edit_allowed allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.claude/settings.local.json" '{}')")"
}

test_contract_rules_reject_weak_checks() {
  local dir; dir=$(new_fixture weak-checks)
  start_session "$dir"
  local check
  for check in './run-tests.sh || true' './run-tests.sh | tail -5' './run-tests.sh || exit 0' './run-tests.sh; exit 0' 'echo ok' 'true'; do
    mkdir -p "$dir/.proof"
    printf '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"%s"}]}' "$check" > "$dir/.proof/contract.json"
    expect_decision "weak_check_rejected [$check]" block "$(hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "")")"
  done
  printf '{"goal":"g","kind":"fix","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}' > "$dir/.proof/contract.json"
  expect_decision unknown_kind_rejected block "$(hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "")")"
  printf '{"goal":"g","kind":"bugfix","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}' > "$dir/.proof/contract.json"
  expect_decision bugfix_without_fail_first_rejected block "$(hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "")")"
  printf '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"npm run lint && npm test"}]}' > "$dir/.proof/contract.json"
  expect_decision chained_with_and_accepted allow "$(hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "")")"
}

test_existing_tests_are_read_only_even_for_additions() {
  local dir; dir=$(new_fixture read-only)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  expect_decision changing_assertion_denied deny "$(hook proof-guard-edit.sh "$(replace_payload "$dir" "$dir/tests/test_cart.py" 'total([3, 4]), 7' 'total([3, 4]), 8')")"
  expect_decision inserting_early_return_denied deny "$(hook proof-guard-edit.sh "$(replace_payload "$dir" "$dir/tests/test_cart.py" '    def test_sums_prices(self):' '    def test_sums_prices(self):
        return')")"
  expect_decision appending_override_denied deny "$(hook proof-guard-edit.sh "$(replace_payload "$dir" "$dir/tests/test_cart.py" 'if __name__' 'TotalTest.test_sums_prices = lambda self: None

if __name__')")"
  expect_decision multi_edit_addition_denied deny "$(hook proof-guard-edit.sh "$(multi_edit_payload "$dir" "$dir/tests/test_cart.py" 'if __name__' 'x = 1
if __name__')")"
  expect_decision new_test_file_allowed allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/tests/test_coupon.py" "$NEW_TEST")")"
  printf 'TotalTest = None\n' >> "$dir/tests/test_cart.py"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  expect_decision stop_after_shell_append_to_existing_test_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_declared_test_change_is_allowed() {
  local dir; dir=$(new_fixture declared)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}],"allowed_test_changes":[{"path":"tests/test_cart.py","reason":"the rule changed"}]}'
  expect_decision declared_test_edit_allowed allow "$(hook proof-guard-edit.sh "$(replace_payload "$dir" "$dir/tests/test_cart.py" 'total([3, 4]), 7' 'total([3, 4]), 8')")"
}

test_skip_and_focus_markers_are_blocked_in_new_tests() {
  local dir; dir=$(new_fixture markers)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  local marker
  for marker in '@unittest.skip("later")' '@unittest.expectedFailure' '@pytest.mark.xfail' 'self.skipTest("x")' 'it.only("x", () => {})' 'fit("x", () => {})' 'throw XCTSkip("x")' 'test("x", () {}, skip: true);'; do
    expect_decision "marker_denied [$marker]" deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/tests/test_new.py" "$marker")")"
  done
}

test_mobile_and_other_test_layouts_are_recognised() {
  local dir; dir=$(new_fixture layouts)
  mkdir -p "$dir/app/src/androidTest" "$dir/shared/src/commonTest" "$dir/Tests/AppTests" "$dir/src/latest"
  printf 'class A\n' > "$dir/app/src/androidTest/A.kt"
  printf 'class B\n' > "$dir/shared/src/commonTest/B.kt"
  printf 'class C\n' > "$dir/Tests/AppTests/CTests.swift"
  printf 'class D\n' > "$dir/app/src/FooTest.kt"
  printf 'x\n' > "$dir/src/latest/notes.kt"
  git -C "$dir" add -A && git -C "$dir" -c user.name=f -c user.email=f@example.invalid commit -qm layouts
  start_session "$dir"
  write_contract "$dir" "$CHANGE_CONTRACT"
  local path
  for path in app/src/androidTest/A.kt shared/src/commonTest/B.kt Tests/AppTests/CTests.swift app/src/FooTest.kt; do
    expect_decision "protected [$path]" deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/$path" "x")")"
  done
  expect_decision not_a_test_folder_allowed allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/src/latest/notes.kt" "y")")"
}

test_proof_records_and_plugin_scripts_are_off_limits() {
  local dir; dir=$(new_fixture records)
  start_session "$dir"
  write_contract "$dir" "$CHANGE_CONTRACT"
  expect_decision forging_with_recorder_denied deny "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "printf '{}' | bash $SCRIPTS/proof-record-evidence.sh pass")")"
  expect_decision touching_state_denied deny "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "rm -rf .git/craft-proof")")"
  expect_decision shell_write_into_proof_denied deny "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "echo '{}' > .proof/contract.json")")"
  expect_decision writing_other_proof_file_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/evidence.jsonl" "{}")")"
  hook proof-record-evidence.sh "$(bash_payload "$dir" ./run-tests.sh)" pass > /dev/null
  expect_equal recorder_ignores_input_that_is_not_a_tool_result 0 "$(evidence_count "$dir")"
}

test_deleting_the_contract_or_cleaning_the_tree_does_not_open_the_gate() {
  local dir; dir=$(new_fixture clean)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  git -C "$dir" clean -fdXq
  expect_decision stop_after_git_clean_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
  local other; other=$(new_fixture missing-state)
  start_session "$other"
  printf '%s' "$FIXED_CART" > "$other/cart.py"
  mv "$(state_of "$other")" "$WORK_ROOT/moved-state"
  expect_decision stop_with_state_removed_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$other")")"
}

test_background_runs_are_not_proof() {
  local dir; dir=$(new_fixture background)
  start_session "$dir"
  write_contract "$dir" "$CHANGE_CONTRACT"
  hook proof-record-evidence.sh "$(result_payload "$dir" ./run-tests.sh 0 true)" pass > /dev/null
  expect_equal background_run_not_recorded 0 "$(evidence_count "$dir" pass)"
}

test_red_must_come_from_the_real_test_not_a_missing_or_swapped_script() {
  local dir; dir=$(new_fixture swapped)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"bugfix","claims":[{"id":"C1","claim":"c","check":"./verify.sh","fail_first":true}]}'
  expect_equal missing_script_run_fails fail "$(run_check "$dir" ./verify.sh)"
  expect_equal missing_program_not_counted_as_red 0 "$(evidence_count "$dir" fail)"
  printf '#!/bin/bash\nexit 1\n' > "$dir/verify.sh"; chmod +x "$dir/verify.sh"
  run_check "$dir" ./verify.sh > /dev/null
  printf '#!/bin/bash\nexit 0\n' > "$dir/verify.sh"
  run_check "$dir" ./verify.sh > /dev/null
  expect_decision stop_after_swapping_check_script_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_red_then_green_needs_same_tests_and_changed_code() {
  local dir; dir=$(new_fixture weakened-test)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  printf '%s' "$NEW_TEST" > "$dir/tests/test_coupon.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  printf 'import unittest\n' > "$dir/tests/test_coupon.py"
  printf '# touched\n' >> "$dir/cart.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  expect_decision stop_after_weakening_new_test_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_happy_path_red_then_green_on_current_code() {
  local dir; dir=$(new_fixture happy)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  printf '%s' "$NEW_TEST" > "$dir/tests/test_coupon.py"
  expect_equal red_run_fails fail "$(run_check "$dir" ./run-tests.sh)"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  expect_equal green_run_passes pass "$(run_check "$dir" ./run-tests.sh)"
  local verdict; verdict=$(hook proof-stop-gate.sh "$(stop_payload "$dir")")
  expect_decision stop_after_red_then_green_allowed allow "$verdict"
  expect_equal stop_tells_user_claims_proven 1 "$(printf '%s' "$verdict" | "$JQ" -r '.systemMessage' | grep -c 'claims proven')"
  printf 'More notes\n' >> "$dir/README.md"
  expect_decision doc_edit_after_proof_keeps_it_fresh allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
  printf '# later\n' >> "$dir/cart.py"
  expect_decision code_edit_after_proof_makes_it_stale block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_stop_blocks_without_proof() {
  local dir; dir=$(new_fixture no-proof)
  start_session "$dir"
  expect_decision stop_without_changes_allowed allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  expect_decision stop_without_contract_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  expect_decision stop_never_run_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir" true)")"
  run_check "$dir" ./run-tests.sh > /dev/null
  expect_decision stop_without_red_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir" true)")"
}

test_contract_locks_when_a_check_program_runs_in_any_form() {
  local dir; dir=$(new_fixture peek)
  start_session "$dir"
  write_contract "$dir" "$CHANGE_CONTRACT"
  expect_decision contract_editable_before_any_run allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" '{"goal":"other","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}')")"
  hook proof-guard-bash.sh "$(bash_payload "$dir" "./run-tests.sh 2>&1 | tail -3")" > /dev/null
  expect_decision changing_goal_after_peek_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" '{"goal":"other","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}')")"
  expect_decision adding_a_claim_after_lock_allowed allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"},{"id":"C2","claim":"d","check":"./run-tests.sh"}]}')")"
  expect_decision upper_case_path_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.PROOF/contract.json" '{}')")"
  expect_decision dot_dot_path_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/nope/../.proof/contract.json" '{}')")"
}

test_checks_count_only_from_the_project_root() {
  local dir; dir=$(new_fixture subfolder)
  start_session "$dir"
  write_contract "$dir" "$CHANGE_CONTRACT"
  mkdir -p "$dir/sub" && printf '#!/bin/bash\nexit 0\n' > "$dir/sub/run-tests.sh" && chmod +x "$dir/sub/run-tests.sh"
  hook proof-record-evidence.sh "$(result_payload "$dir/sub" ./run-tests.sh 0)" pass > /dev/null
  expect_equal run_from_subfolder_not_recorded 0 "$(evidence_count "$dir")"
  mkdir -p "$dir/.scratch" && git -C "$dir/.scratch" init -q
  expect_decision nested_repo_does_not_escape_rules deny "$(CLAUDE_PROJECT_DIR="$dir" hook proof-guard-edit.sh "$(edit_payload "$dir/.scratch" Edit "$dir/tests/test_cart.py" x)")"
}

test_files_written_by_checks_do_not_make_proof_stale() {
  local dir; dir=$(new_fixture outputs)
  printf '#!/bin/bash\ndate +%%s%%N > report.xml\n' > "$dir/c1.sh"; cp "$dir/c1.sh" "$dir/c2.sh"; chmod +x "$dir"/c?.sh
  git -C "$dir" add -A && git -C "$dir" -c user.name=f -c user.email=f@example.invalid commit -qm checks
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"a","check":"./c1.sh"},{"id":"C2","claim":"b","check":"./c2.sh"}]}'
  printf '# change\n' >> "$dir/cart.py"
  run_check "$dir" ./c1.sh > /dev/null; run_check "$dir" ./c2.sh > /dev/null; run_check "$dir" ./c1.sh > /dev/null
  expect_decision both_checks_stay_fresh allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_stop_gives_up_only_after_three_identical_blocks() {
  local dir; dir=$(new_fixture loop)
  start_session "$dir"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  expect_decision first_stop_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir" false)")"
  expect_decision second_identical_stop_still_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir" true)")"
  local third; third=$(hook proof-stop-gate.sh "$(stop_payload "$dir" true)")
  expect_decision third_identical_stop_lets_turn_end allow "$third"
  expect_equal giving_up_tells_user 1 "$(printf '%s' "$third" | "$JQ" -r '.systemMessage' | grep -c 'unproven')"
}

test_unverified_items_are_shown_to_the_user() {
  local dir; dir=$(new_fixture unverified)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}],"unverified":["delivery to the production webhook"]}'
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  local verdict; verdict=$(hook proof-stop-gate.sh "$(stop_payload "$dir" false "All done.")")
  expect_decision stop_allowed_regardless_of_wording allow "$verdict"
  expect_equal user_sees_unverified_item 1 "$(printf '%s' "$verdict" | "$JQ" -r '.systemMessage' | grep -c 'Not verified: delivery to the production webhook')"
}

test_new_task_after_a_proven_one_starts_a_fresh_contract() {
  local dir; dir=$(new_fixture next-task)
  start_session "$dir"
  write_contract "$dir" "$CHANGE_CONTRACT"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  hook proof-stop-gate.sh "$(stop_payload "$dir")" > /dev/null
  hook proof-user-prompt.sh "$("$JQ" -nc --arg cwd "$dir" '{hook_event_name: "UserPromptSubmit", cwd: $cwd, prompt: "next"}')" > /dev/null
  expect_decision new_contract_allowed_for_next_task allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" '{"goal":"next","kind":"change","claims":[{"id":"C9","claim":"c","check":"./run-tests.sh"}]}')")"
}

test_clear_archives_an_unfinished_contract_but_keeps_its_changes_counted() {
  local dir; dir=$(new_fixture cleared)
  start_session "$dir"
  write_contract "$dir" "$CHANGE_CONTRACT"
  run_check "$dir" ./run-tests.sh > /dev/null
  printf '# unproven edit\n' >> "$dir/cart.py"
  start_session "$dir" clear
  expect_decision contract_writable_after_clear allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" '{}')")"
  expect_decision earlier_unproven_edit_still_counts block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_shell_guard_is_precise() {
  local dir; dir=$(new_fixture shell)
  printf '' > "$dir/tests/__init__.py"
  mkdir -p "$dir/src/pkg"
  git -C "$dir" add -A && git -C "$dir" -c user.name=f -c user.email=f@example.invalid commit -qm pkg
  start_session "$dir"
  expect_decision sed_on_protected_test_denied deny "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "sed -i '' 's/7/8/' tests/test_cart.py")")"
  expect_decision perl_in_place_on_test_denied deny "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "perl -pi -e 's/7/8/' tests/test_cart.py")")"
  expect_decision same_file_name_elsewhere_allowed allow "$(hook proof-guard-bash.sh "$(bash_payload "$dir" 'echo "" > src/pkg/__init__.py')")"
  expect_decision arrow_inside_quotes_allowed allow "$(hook proof-guard-bash.sh "$(bash_payload "$dir" 'grep -n "a->b" tests/test_cart.py')")"
  expect_decision running_tests_with_redirect_allowed allow "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "/usr/bin/python3 -m unittest tests/test_cart.py 2>&1")")"
  expect_decision no_verify_denied deny "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "git commit --no-verify -m x")")"
}

test_check_matching_ignores_cd_prefix_absolute_path_and_spaces_in_ids() {
  local dir; dir=$(new_fixture normalize)
  start_session "$dir"
  write_contract "$dir" "{\"goal\":\"g\",\"kind\":\"change\",\"claims\":[{\"id\":\"Claim one\",\"claim\":\"c\",\"check\":\"cd $dir && ./run-tests.sh\"}]}"
  hook proof-record-evidence.sh "$(result_payload "$dir" "./run-tests.sh" 0)" pass > /dev/null
  hook proof-record-evidence.sh "$(result_payload "$dir" "$dir/run-tests.sh" 0)" pass > /dev/null
  expect_equal both_forms_recorded_for_id_with_space 2 "$("$JQ" -s 'map(select(.claim == "Claim one")) | length' "$(state_of "$dir")/evidence.jsonl")"
}

test_escape_hatch_turns_the_rules_off() {
  local dir; dir=$(new_fixture escape)
  start_session "$dir"
  expect_decision env_rules_off_allows_edit allow "$(CLAUDE_CRAFT_RULES=off hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/cart.py" x)")"
  expect_decision command_prefix_allows_shell_write allow "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "CLAUDE_CRAFT_RULES=off sed -i '' 's/7/8/' tests/test_cart.py")")"
}

new_folder() {
  local dir="$WORK_ROOT/$1"
  mkdir -p "$dir"
  printf '%s' "$dir"
}

write_file() {
  local dir=$1 path=$2 text=$3
  mkdir -p "$(dirname "$dir/$path")"
  printf '%s' "$text" > "$dir/$path"
  hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/$path" "$text")" > /dev/null
}

PLAN='# Rollout plan

## Risks
Rollback takes 5 minutes.

Monthly cost: 50400 rupees a year.
'

test_outside_git_a_deliverable_needs_a_covering_contract() {
  local dir; dir=$(new_folder plain-folder)
  start_session "$dir"
  expect_decision deliverable_without_contract_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/plan.md" "$PLAN")")"
  write_contract "$dir" '{"goal":"A rollout plan with its risks","kind":"deliverable","claims":[{"id":"C1","claim":"The plan lists risks and a rollback","file":{"path":"plan.md","contains":["^## Risks","[Rr]ollback"]}}]}'
  expect_decision deliverable_with_contract_allowed allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/plan.md" "$PLAN")")"
  write_file "$dir" plan.md "$PLAN"
  write_file "$dir" notes.md "stray notes"
  expect_decision uncovered_deliverable_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
  local other; other=$(new_folder plain-folder-covered)
  start_session "$other"
  write_contract "$other" '{"goal":"A rollout plan with its risks","kind":"deliverable","claims":[{"id":"C1","claim":"The plan lists risks and a rollback","file":{"path":"plan.md","contains":["^## Risks","[Rr]ollback"]}}]}'
  write_file "$other" plan.md "$PLAN"
  expect_decision covered_deliverable_allowed allow "$(hook proof-stop-gate.sh "$(stop_payload "$other")")"
  expect_equal state_kept_in_proof_folder 1 "$([ -d "$other/.proof/state" ] && printf 1 || printf 0)"
}

test_file_claims_check_the_final_content() {
  local dir; dir=$(new_folder file-claim)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"Plan has a timeline","file":{"path":"plan.md","contains":["^## Timeline"]}}]}'
  write_file "$dir" plan.md "$PLAN"
  expect_decision missing_section_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_source_claims_reopen_the_source() {
  local dir; dir=$(new_folder sources)
  printf '<html><body><p>The free tier allows <b>100 requests</b> per minute.</p></body></html>' > "$dir/pricing.html"
  start_session "$dir"
  write_contract "$dir" "{\"goal\":\"g\",\"kind\":\"deliverable\",\"claims\":[{\"id\":\"C1\",\"claim\":\"Rate limit is 100 per minute\",\"source\":{\"location\":\"file://$dir/pricing.html\",\"quote\":\"allows 100 requests per minute\"}},{\"id\":\"C2\",\"claim\":\"Summary exists\",\"file\":{\"path\":\"summary.md\",\"contains\":[\"100\"]}}]}"
  write_file "$dir" summary.md "Limit: 100 per minute"
  expect_decision quote_found_through_html_allowed allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
  local other; other=$(new_folder sources-wrong)
  printf 'The free tier allows 60 requests per minute.\n' > "$other/pricing.txt"
  start_session "$other"
  write_contract "$other" '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"Rate limit is 100 per minute","source":{"location":"pricing.txt","quote":"allows 100 requests per minute"}},{"id":"C2","claim":"Summary exists","file":{"path":"summary.md","contains":["100"]}}]}'
  write_file "$other" summary.md "Limit: 100 per minute"
  expect_decision quote_missing_from_source_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$other")")"
}

test_calc_claims_are_recomputed() {
  local dir; dir=$(new_folder calc-right)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"Yearly cost","calc":{"expression":"4200 * 12","result":"50,400"}},{"id":"C2","claim":"Plan states it","file":{"path":"plan.md","contains":["50400"]}}]}'
  write_file "$dir" plan.md "$PLAN"
  expect_decision correct_number_allowed allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
  local other; other=$(new_folder calc-wrong)
  start_session "$other"
  write_contract "$other" '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"Yearly cost","calc":{"expression":"4200 * 12","result":"54000"}},{"id":"C2","claim":"Plan states it","file":{"path":"plan.md","contains":["Rollback"]}}]}'
  write_file "$other" plan.md "$PLAN"
  expect_decision wrong_number_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$other")")"
}

test_rubric_claims_go_to_a_judge_once() {
  local fake="$WORK_ROOT/fake-judge"
  mkdir -p "$fake"
  cat > "$fake/claude" <<'EOF'
#!/bin/bash
printf 'call\n' >> "$(dirname "$0")/calls"
case "${*: -1}" in *PASSME*) printf '{"pass": true, "reason": "fine"}\n' ;; *) printf '{"pass": false, "reason": "the plan has no owner for each risk"}\n' ;; esac
EOF
  chmod +x "$fake/claude"
  local dir; dir=$(new_folder rubric)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"Each risk has an owner","rubric":{"target":"plan.md","criteria":"PASS if every risk names an owner."}}]}'
  write_file "$dir" plan.md "$PLAN"
  local verdict; verdict=$(PATH="$fake:$PATH" hook proof-stop-gate.sh "$(stop_payload "$dir")")
  expect_decision failing_rubric_blocked block "$verdict"
  expect_equal judge_reason_reaches_claude 1 "$(printf '%s' "$verdict" | "$JQ" -r '.reason' | grep -c 'no owner for each risk')"
  PATH="$fake:$PATH" hook proof-stop-gate.sh "$(stop_payload "$dir" true)" > /dev/null
  expect_equal same_content_judged_once 1 "$(wc -l < "$fake/calls" | tr -d ' ')"
  write_file "$dir" plan.md "$PLAN PASSME"
  expect_decision passing_rubric_allowed allow "$(PATH="$fake:$PATH" hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_contract_shape_rules_for_evidence() {
  local dir; dir=$(new_folder shapes)
  start_session "$dir"
  mkdir -p "$dir/.proof"
  printf '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"c","check":"./x.sh","file":{"path":"a.md","contains":["x"]}}]}' > "$dir/.proof/contract.json"
  expect_decision two_kinds_of_evidence_rejected block "$(hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "")")"
  printf '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"c","file":{"path":"a.md","contains":["x"]},"fail_first":true}]}' > "$dir/.proof/contract.json"
  expect_decision fail_first_without_check_rejected block "$(hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "")")"
  printf '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"c","source":{"location":"a.md","quote":"short"}}]}' > "$dir/.proof/contract.json"
  expect_decision too_short_quote_rejected block "$(hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "")")"
}

todo_item() {
  local session=$1 id=$2 subject=$3 status=$4 description=${5:-}
  mkdir -p "$CLAUDE_CONFIG_DIR/tasks/$session"
  "$JQ" -n --arg id "$id" --arg s "$subject" --arg st "$status" --arg d "$description" \
    '{id: $id, subject: $s, description: $d, status: $st, activeForm: "", blocks: [], blockedBy: []}' > "$CLAUDE_CONFIG_DIR/tasks/$session/$id.json"
}

session_edit_payload() {
  "$JQ" -nc --arg cwd "$1" --arg path "$2" --arg s "$3" --arg agent "${4:-}" \
    '{hook_event_name: "PreToolUse", tool_name: "Write", session_id: $s, cwd: $cwd, tool_input: {file_path: $path, content: "x"}} + (if $agent != "" then {agent_id: $agent} else {} end)'
}

task_payload() {
  "$JQ" -nc --arg cwd "$1" --arg subject "$2" --arg description "${3:-}" \
    '{hook_event_name: "TaskCompleted", cwd: $cwd, task_id: "1", task_subject: $subject, task_description: $description}'
}

session_stop_payload() {
  "$JQ" -nc --arg cwd "$1" --arg s "$2" '{hook_event_name: "Stop", session_id: $s, cwd: $cwd, stop_hook_active: false, last_assistant_message: "Done."}'
}

task_gate_exit() {
  printf '%s' "$2" | /bin/bash "$SCRIPTS/proof-task-gate.sh" > /dev/null 2>&1
  printf '%s' "$?"
}

THREE_CLAIMS='{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"a","check":"./run-tests.sh"},{"id":"C2","claim":"b","check":"./run-tests.sh"},{"id":"C3","claim":"c","check":"./run-tests.sh"}]}'

test_three_or_more_claims_need_a_todo_list_before_editing() {
  local dir; dir=$(new_fixture todo-first)
  start_session "$dir"
  write_contract "$dir" "$THREE_CLAIMS"
  expect_decision edit_without_todo_list_denied deny "$(hook proof-guard-edit.sh "$(session_edit_payload "$dir" "$dir/cart.py" s-none)")"
  todo_item s-listed 1 "C1: zero total" pending
  expect_decision edit_with_todo_list_allowed allow "$(hook proof-guard-edit.sh "$(session_edit_payload "$dir" "$dir/cart.py" s-listed)")"
  expect_decision edit_inside_subagent_allowed allow "$(hook proof-guard-edit.sh "$(session_edit_payload "$dir" "$dir/cart.py" s-none agent-1)")"
}

test_todo_item_completes_only_when_its_claim_is_proven() {
  local dir; dir=$(new_fixture todo-gate)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"a","check":"./run-tests.sh"},{"id":"C10","claim":"b","check":"./run-tests.sh"}]}'
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  expect_equal unproven_claim_item_refused 2 "$(task_gate_exit "$dir" "$(task_payload "$dir" "C1: total is never negative")")"
  expect_equal item_naming_no_claim_allowed 0 "$(task_gate_exit "$dir" "$(task_payload "$dir" "Read the checkout code")")"
  run_check "$dir" ./run-tests.sh > /dev/null
  expect_equal proven_claim_item_allowed 0 "$(task_gate_exit "$dir" "$(task_payload "$dir" "C1: total is never negative")")"
  printf '# later\n' >> "$dir/cart.py"
  expect_equal stale_claim_item_refused 2 "$(task_gate_exit "$dir" "$(task_payload "$dir" "Finish" "Covers C10")")"
}

test_stop_checks_the_todo_list() {
  local dir; dir=$(new_folder todo-stop)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"a","file":{"path":"plan.md","contains":["Risks"]}},{"id":"C2","claim":"b","file":{"path":"plan.md","contains":["Rollback"]}},{"id":"C3","claim":"c","file":{"path":"plan.md","contains":["rupees"]}}]}'
  write_file "$dir" plan.md "$PLAN"
  todo_item s-stop 1 "C1: risks" completed
  todo_item s-stop 2 "C2: rollback" completed
  expect_decision claim_not_named_by_any_item_blocked block "$(hook proof-stop-gate.sh "$(session_stop_payload "$dir" s-stop)")"
  todo_item s-stop 3 "C3: cost line" in_progress
  expect_decision open_item_blocked block "$(hook proof-stop-gate.sh "$(session_stop_payload "$dir" s-stop)")"
  todo_item s-stop 3 "C3: cost line" in_progress "Blocked: finance has not confirmed the rate"
  expect_decision blocked_item_allowed allow "$(hook proof-stop-gate.sh "$(session_stop_payload "$dir" s-stop)")"
}

test_home_folder_repository_is_not_the_project() {
  local home="$WORK_ROOT/dotfiles-home"
  mkdir -p "$home/work"
  git -C "$home" init -q
  local work="$home/work"
  local event
  event=$("$JQ" -nc --arg c "$work" '{hook_event_name: "SessionStart", source: "startup", cwd: $c}')
  printf '%s' "$event" | HOME="$home" CLAUDE_PROJECT_DIR="$work" /bin/bash "$SCRIPTS/proof-session-start.sh" > /dev/null 2>&1
  expect_decision contract_write_in_project_allowed allow "$(printf '%s' "$(edit_payload "$work" Write "$work/.proof/contract.json" '{}')" | HOME="$home" CLAUDE_PROJECT_DIR="$work" /bin/bash "$SCRIPTS/proof-guard-edit.sh" 2>/dev/null)"
  expect_equal state_kept_in_project_not_home 1 "$([ -d "$work/.proof/state" ] && printf 1 || printf 0)"
}

test_missing_contract_message_gives_the_exact_path() {
  local dir; dir=$(new_fixture exact-path)
  mkdir -p "$dir/pkg"
  start_session "$dir"
  local denial; denial=$(hook proof-guard-edit.sh "$(edit_payload "$dir/pkg" Write "$dir/pkg/a.py" x)")
  expect_equal denial_names_contract_path 1 "$(printf '%s' "$denial" | "$JQ" -r '.hookSpecificOutput.permissionDecisionReason' | grep -c -F "$(cd "$dir" && pwd -P)/.proof/contract.json")"
}

test_deliverable_contract_locks_on_first_finish_attempt() {
  local dir; dir=$(new_folder lock-on-stop)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"Plan has a timeline","file":{"path":"plan.md","contains":["^## Timeline"]}}]}'
  write_file "$dir" plan.md "$PLAN"
  hook proof-stop-gate.sh "$(stop_payload "$dir")" > /dev/null
  expect_decision weakening_claim_after_finish_attempt_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" '{"goal":"g","kind":"deliverable","claims":[{"id":"C1","claim":"Plan has a title","file":{"path":"plan.md","contains":["^# "]}}]}')")"
}

test_messages_point_to_the_skills() {
  local dir; dir=$(new_fixture skills)
  local context denial
  context=$(hook proof-session-start.sh "$("$JQ" -nc --arg cwd "$dir" '{hook_event_name: "SessionStart", source: "startup", cwd: $cwd}')")
  denial=$(hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/cart.py" x)")
  expect_equal session_context_names_contract_skill 1 "$(printf '%s' "$context" | "$JQ" -r '.hookSpecificOutput.additionalContext' | grep -c 'craft-proof:contract' || true)"
  expect_equal denial_names_testing_skill 1 "$(printf '%s' "$denial" | "$JQ" -r '.hookSpecificOutput.permissionDecisionReason' | grep -c 'craft-proof:testing-best-practices' || true)"
}

test_fast_lint_reports_problems_in_the_edited_file() {
  local dir; dir=$(new_fixture lint)
  printf '{"a": 1,,}' > "$dir/broken.json"
  printf '{"a": 1}' > "$dir/ok.json"
  printf '[package]\nname = "x"\n' > "$dir/Cargo.toml"
  expect_decision invalid_json_reported block "$(hook lint-edited-file.sh "$(edit_payload "$dir" Edit "$dir/broken.json" x)")"
  expect_decision valid_json_passes allow "$(hook lint-edited-file.sh "$(edit_payload "$dir" Edit "$dir/ok.json" x)")"
  expect_decision no_linter_for_type_passes allow "$(hook lint-edited-file.sh "$(edit_payload "$dir" Edit "$dir/Cargo.toml" x)")"
}

for test_name in $(declare -F | awk '{print $3}' | grep '^test_'); do
  "$test_name"
done

printf '%s\n' "$failures"
printf 'passed %d, failed %d\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
