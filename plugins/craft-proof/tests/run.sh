#!/bin/bash
set -uo pipefail
unset CLAUDE_CRAFT_RULES

PLUGIN_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPTS="$PLUGIN_ROOT/scripts"
WORK_ROOT=$(mktemp -d -t proof-tests)
JQ=$(command -v jq || printf '/usr/bin/jq')
passed=0
failed=0
failures=""

new_fixture() {
  local dir="$WORK_ROOT/$1"
  mkdir -p "$dir/tests"
  cat > "$dir/cart.py" <<'EOF'
def total(prices, coupon=0):
    return sum(prices) - coupon
EOF
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

hook() {
  local script=$1 payload=$2
  shift 2
  printf '%s' "$payload" | /bin/bash "$SCRIPTS/$script" "$@"
}

start_session() {
  hook proof-session-start.sh "$("$JQ" -nc --arg cwd "$1" '{hook_event_name: "SessionStart", source: "startup", cwd: $cwd}')" > /dev/null
}

edit_payload() {
  "$JQ" -nc --arg cwd "$1" --arg tool "$2" --arg path "$3" --arg text "$4" \
    '{hook_event_name: "PreToolUse", tool_name: $tool, cwd: $cwd, tool_input: (if $tool == "Write" then {file_path: $path, content: $text} else {file_path: $path, old_string: "x", new_string: $text} end)}'
}

bash_payload() {
  "$JQ" -nc --arg cwd "$1" --arg cmd "$2" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $cwd, tool_input: {command: $cmd}}'
}

stop_payload() {
  "$JQ" -nc --arg cwd "$1" --argjson active "${2:-false}" --arg msg "${3:-Done.}" \
    '{hook_event_name: "Stop", cwd: $cwd, stop_hook_active: $active, last_assistant_message: $msg}'
}

write_contract() {
  printf '%s' "$2" > "$1/.proof/contract.json"
}

run_check() {
  local dir=$1 check=$2 result
  if (cd "$dir" && eval "$check" > /dev/null 2>&1); then result=pass; else result=fail; fi
  hook proof-record-evidence.sh "$(bash_payload "$dir" "$check")" "$result" > /dev/null
  printf '%s' "$result"
}

decision_of() {
  printf '%s' "$1" | "$JQ" -r '.hookSpecificOutput.permissionDecision // .decision // "allow"' 2>/dev/null || printf 'allow'
}

expect_decision() {
  local name=$1 expected=$2 output=$3 actual
  actual=$(decision_of "$output")
  [ -n "$output" ] || actual=allow
  if [ "$actual" = "$expected" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    failures="$failures
FAIL $name: expected $expected, got $actual
$output"
  fi
}

expect_equal() {
  local name=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    failures="$failures
FAIL $name: expected [$expected], got [$actual]"
  fi
}

BUGFIX_CONTRACT='{"goal":"Total never goes below zero","kind":"bugfix","claims":[{"id":"C1","claim":"A coupon larger than the cart gives 0","check":"./run-tests.sh","fail_first":true}]}'
NEW_TEST='import unittest
from cart import total


class OversizedCouponTest(unittest.TestCase):
    def test_total_is_zero_when_coupon_exceeds_cart(self):
        self.assertEqual(total([5], coupon=9), 0)
'
FIXED_CART='def total(prices, coupon=0):
    return max(0, sum(prices) - coupon)
'

test_session_start_records_baseline_and_hides_state_from_git() {
  local dir; dir=$(new_fixture session-start)
  start_session "$dir"
  expect_equal session_start_baseline_lists_test_file "1" "$(cut -f2 "$dir/.proof/baseline.tsv" | grep -c '^tests/test_cart.py$')"
  expect_equal session_start_state_not_in_git_status "" "$(git -C "$dir" status --porcelain)"
}

test_code_edit_without_contract_is_denied() {
  local dir; dir=$(new_fixture no-contract)
  start_session "$dir"
  expect_decision code_edit_without_contract_is_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/cart.py" "x")")"
}

test_doc_edit_without_contract_is_allowed() {
  local dir; dir=$(new_fixture doc-edit)
  start_session "$dir"
  expect_decision doc_edit_without_contract_is_allowed allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/README.md" "x")")"
}

test_contract_with_check_that_cannot_fail_is_rejected() {
  local dir; dir=$(new_fixture trivial-check)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh || true"}]}'
  expect_decision trivial_check_rejected block "$(hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "")")"
}

test_bugfix_contract_without_fail_first_is_rejected() {
  local dir; dir=$(new_fixture no-fail-first)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"bugfix","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}'
  expect_decision bugfix_without_fail_first_rejected block "$(hook proof-after-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "")")"
}

replace_payload() {
  "$JQ" -nc --arg cwd "$1" --arg path "$2" --arg old "$3" --arg new "$4" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", cwd: $cwd, tool_input: {file_path: $path, old_string: $old, new_string: $new}}'
}

test_existing_test_may_gain_tests_but_not_change_original_lines() {
  local dir; dir=$(new_fixture grow-only)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  expect_decision adding_test_to_existing_file_allowed allow "$(hook proof-guard-edit.sh "$(replace_payload "$dir" "$dir/tests/test_cart.py" 'if __name__' "    def test_oversized_coupon(self):
        self.assertEqual(total([5], coupon=9), 0)


if __name__")")"
  expect_decision changing_original_assertion_denied deny "$(hook proof-guard-edit.sh "$(replace_payload "$dir" "$dir/tests/test_cart.py" 'total([3, 4]), 7' 'total([3, 4]), 8')")"
  printf '\n\nclass ExtraTest(unittest.TestCase):\n    def test_empty_cart(self):\n        self.assertEqual(total([]), 0)\n' >> "$dir/tests/test_cart.py"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  hook proof-record-evidence.sh "$(bash_payload "$dir" ./run-tests.sh)" fail > /dev/null
  run_check "$dir" ./run-tests.sh > /dev/null
  expect_decision stop_after_appending_to_existing_test_allowed allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_check_matches_command_with_cd_prefix_or_absolute_path() {
  local dir; dir=$(new_fixture normalize)
  start_session "$dir"
  write_contract "$dir" "{\"goal\":\"g\",\"kind\":\"change\",\"claims\":[{\"id\":\"C1\",\"claim\":\"c\",\"check\":\"cd $dir && ./run-tests.sh\"},{\"id\":\"C2\",\"claim\":\"c\",\"check\":\"./run-tests.sh\"}]}"
  hook proof-record-evidence.sh "$(bash_payload "$dir" "./run-tests.sh")" pass > /dev/null
  hook proof-record-evidence.sh "$(bash_payload "$dir" "$dir/run-tests.sh")" pass > /dev/null
  expect_equal cd_prefixed_check_matches_plain_run 2 "$("$JQ" -s 'map(select(.claim == "C1")) | length' "$dir/.proof/evidence.jsonl")"
  expect_equal absolute_path_run_matches_relative_check 2 "$("$JQ" -s 'map(select(.claim == "C2")) | length' "$dir/.proof/evidence.jsonl")"
}

test_existing_test_edit_is_denied_unless_declared() {
  local dir; dir=$(new_fixture protected)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  expect_decision existing_test_edit_denied deny "$(hook proof-guard-edit.sh "$(replace_payload "$dir" "$dir/tests/test_cart.py" 'total([10], coupon=4), 6' 'total([10], coupon=4), 5')")"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}],"allowed_test_changes":[{"path":"tests/test_cart.py","reason":"user changed the rule"}]}'
  expect_decision declared_test_edit_allowed allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/tests/test_cart.py" "x")")"
}

test_new_test_file_is_allowed_but_not_with_skip_marker() {
  local dir; dir=$(new_fixture new-test)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  expect_decision new_test_file_allowed allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/tests/test_coupon.py" "$NEW_TEST")")"
  expect_decision new_test_with_skip_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/tests/test_coupon.py" "@unittest.skip('later')")")"
}

test_proof_records_cannot_be_written_by_tools() {
  local dir; dir=$(new_fixture records)
  start_session "$dir"
  expect_decision evidence_write_denied deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/evidence.jsonl" "{}")")"
  expect_decision shell_write_into_proof_denied deny "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "echo '{}' >> .proof/evidence.jsonl")")"
}

test_shell_change_to_protected_test_is_denied_but_running_it_is_allowed() {
  local dir; dir=$(new_fixture shell)
  start_session "$dir"
  expect_decision sed_on_protected_test_denied deny "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "sed -i '' 's/7/8/' tests/test_cart.py")")"
  expect_decision running_tests_with_stderr_redirect_allowed allow "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "/usr/bin/python3 -m unittest tests/test_cart.py 2>&1")")"
  expect_decision no_verify_denied deny "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "git commit --no-verify -m x")")"
}

test_contract_locks_after_first_check_run() {
  local dir; dir=$(new_fixture lock)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  expect_decision contract_editable_before_any_run allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "{}")")"
  run_check "$dir" ./run-tests.sh > /dev/null
  expect_decision contract_locked_after_run deny "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Write "$dir/.proof/contract.json" "{}")")"
}

test_stop_allows_when_nothing_changed() {
  local dir; dir=$(new_fixture idle)
  start_session "$dir"
  expect_decision stop_without_changes_allowed allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_stop_blocks_code_change_without_contract() {
  local dir; dir=$(new_fixture stop-no-contract)
  start_session "$dir"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  expect_decision stop_code_change_without_contract_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_stop_allows_red_then_green_on_current_code() {
  local dir; dir=$(new_fixture happy)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  printf '%s' "$NEW_TEST" > "$dir/tests/test_coupon.py"
  expect_equal red_run_fails fail "$(run_check "$dir" ./run-tests.sh)"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  expect_equal green_run_passes pass "$(run_check "$dir" ./run-tests.sh)"
  expect_decision stop_after_red_then_green_allowed allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_stop_blocks_when_claim_was_never_run() {
  local dir; dir=$(new_fixture never-run)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  expect_decision stop_never_run_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_stop_blocks_when_fail_first_claim_was_never_red() {
  local dir; dir=$(new_fixture never-red)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  printf '%s' "$NEW_TEST" > "$dir/tests/test_coupon.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  expect_decision stop_never_red_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_stop_blocks_stale_proof_after_later_edit() {
  local dir; dir=$(new_fixture stale)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  printf '%s' "$NEW_TEST" > "$dir/tests/test_coupon.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  printf '%s\n# later edit\n' "$FIXED_CART" > "$dir/cart.py"
  expect_decision stop_stale_proof_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_stop_blocks_when_protected_test_changed_by_any_tool() {
  local dir; dir=$(new_fixture tampered)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}'
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  printf 'import unittest\n' > "$dir/tests/test_cart.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  expect_decision stop_tampered_test_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_stop_blocks_contract_changed_after_lock() {
  local dir; dir=$(new_fixture relocked)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}'
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  write_contract "$dir" '{"goal":"g2","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}'
  expect_decision stop_contract_changed_after_lock_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_evidence_ignores_command_that_differs_from_check() {
  local dir; dir=$(new_fixture different-command)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}]}'
  hook proof-record-evidence.sh "$(bash_payload "$dir" "./run-tests.sh || true")" pass > /dev/null
  expect_equal different_command_not_recorded 0 "$(cat "$dir/.proof/evidence.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
}

test_stop_gives_up_after_repeating_same_block() {
  local dir; dir=$(new_fixture loop)
  start_session "$dir"
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  expect_decision first_stop_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir" false)")"
  local second; second=$(hook proof-stop-gate.sh "$(stop_payload "$dir" true)")
  expect_decision repeated_same_block_lets_turn_end allow "$second"
  expect_equal repeated_block_tells_user true "$(printf '%s' "$second" | "$JQ" -r 'has("systemMessage")')"
}

test_stop_requires_unverified_items_named_in_final_reply() {
  local dir; dir=$(new_fixture unverified)
  start_session "$dir"
  write_contract "$dir" '{"goal":"g","kind":"change","claims":[{"id":"C1","claim":"c","check":"./run-tests.sh"}],"unverified":["works against the production payment API"]}'
  printf '%s' "$FIXED_CART" > "$dir/cart.py"
  run_check "$dir" ./run-tests.sh > /dev/null
  expect_decision stop_silent_about_unverified_blocked block "$(hook proof-stop-gate.sh "$(stop_payload "$dir" false "All done, it works.")")"
  expect_decision stop_naming_unverified_allowed allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir" false "C1 passes. Unverified: production payment API.")")"
}

multi_edit_payload() {
  "$JQ" -nc --arg cwd "$1" --arg path "$2" --arg old "$3" --arg new "$4" \
    '{hook_event_name: "PreToolUse", tool_name: "MultiEdit", cwd: $cwd, tool_input: {file_path: $path, edits: [{old_string: $old, new_string: $new}]}}'
}

test_multi_edit_follows_the_same_test_rules() {
  local dir; dir=$(new_fixture multi-edit)
  start_session "$dir"
  write_contract "$dir" "$BUGFIX_CONTRACT"
  expect_decision multi_edit_changing_original_assertion_denied deny "$(hook proof-guard-edit.sh "$(multi_edit_payload "$dir" "$dir/tests/test_cart.py" 'total([3, 4]), 7' 'total([3, 4]), 8')")"
  expect_decision multi_edit_adding_test_allowed allow "$(hook proof-guard-edit.sh "$(multi_edit_payload "$dir" "$dir/tests/test_cart.py" 'if __name__' "    def test_more(self):
        self.assertEqual(total([1]), 1)


if __name__")")"
  expect_decision multi_edit_adding_skip_denied deny "$(hook proof-guard-edit.sh "$(multi_edit_payload "$dir" "$dir/tests/test_coupon.py" 'x' '@unittest.skip("later")')")"
}

test_escape_hatch_turns_the_rules_off() {
  local dir; dir=$(new_fixture escape)
  start_session "$dir"
  expect_decision env_rules_off_allows_edit_without_contract allow "$(CLAUDE_CRAFT_RULES=off hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/cart.py" "x")")"
  expect_decision command_prefix_allows_protected_shell_write allow "$(hook proof-guard-bash.sh "$(bash_payload "$dir" "CLAUDE_CRAFT_RULES=off sed -i '' 's/7/8/' tests/test_cart.py")")"
}

test_folders_outside_git_are_left_alone() {
  local dir="$WORK_ROOT/no-git"
  mkdir -p "$dir"
  printf 'x = 1\n' > "$dir/app.py"
  start_session "$dir"
  expect_equal no_state_created_outside_git "" "$(/bin/ls -A "$dir" | /usr/bin/grep -x '.proof' || true)"
  expect_decision edit_outside_git_allowed allow "$(hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/app.py" "x = 2")")"
  printf 'x = 2\n' > "$dir/app.py"
  expect_decision stop_outside_git_allowed allow "$(hook proof-stop-gate.sh "$(stop_payload "$dir")")"
}

test_messages_point_to_the_skills() {
  local dir; dir=$(new_fixture skills)
  local context denial
  context=$(hook proof-session-start.sh "$("$JQ" -nc --arg cwd "$dir" '{hook_event_name: "SessionStart", source: "startup", cwd: $cwd}')")
  denial=$(hook proof-guard-edit.sh "$(edit_payload "$dir" Edit "$dir/cart.py" "x")")
  expect_equal session_context_names_contract_skill 1 "$(printf '%s' "$context" | "$JQ" -r '.hookSpecificOutput.additionalContext' | /usr/bin/grep -c 'craft-proof:contract' || true)"
  expect_equal missing_contract_denial_names_testing_skill 1 "$(printf '%s' "$denial" | "$JQ" -r '.hookSpecificOutput.permissionDecisionReason' | /usr/bin/grep -c 'craft-proof:testing-best-practices' || true)"
}

test_fast_lint_reports_problems_in_the_edited_file() {
  local dir; dir=$(new_fixture lint)
  printf '{"a": 1,,}' > "$dir/broken.json"
  printf '{"a": 1}' > "$dir/ok.json"
  printf '[package]\nname = "x"\n' > "$dir/Cargo.toml"
  expect_decision invalid_json_is_reported block "$(hook lint-edited-file.sh "$(edit_payload "$dir" Edit "$dir/broken.json" x)")"
  expect_decision valid_json_passes allow "$(hook lint-edited-file.sh "$(edit_payload "$dir" Edit "$dir/ok.json" x)")"
  expect_decision file_type_without_linter_passes allow "$(hook lint-edited-file.sh "$(edit_payload "$dir" Edit "$dir/Cargo.toml" x)")"
}

for test_name in $(declare -F | awk '{print $3}' | grep '^test_'); do
  "$test_name"
done

printf '%s\n' "$failures"
printf 'passed %d, failed %d (fixtures in %s)\n' "$passed" "$failed" "$WORK_ROOT"
[ "$failed" -eq 0 ]
