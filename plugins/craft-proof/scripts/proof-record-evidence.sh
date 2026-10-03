#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
proof_active || exit 0

result=${1:-}
case "$result" in pass|fail) ;; *) exit 0 ;; esac
case "$(input_field .hook_event_name)" in PostToolUse|PostToolUseFailure) ;; *) exit 0 ;; esac
[ "$(input_field .tool_name)" = Bash ] || exit 0
[ -n "$(input_field .tool_use_id)" ] || exit 0

contract=$(active_contract)
contract_valid_file "$contract" || exit 0

event_name=$(input_field .hook_event_name)
command_text=$(input_field .tool_input.command)
claim_ids=$("$JQ" -r --arg c "$command_text" --arg root "$ROOT" --arg physical "$ROOT_PHYSICAL" --arg cwd "$CWD_PHYSICAL" --arg given "$INPUT_CWD" "$normalize_command_jq"'
  [$root, $physical, $cwd, $given] as $roots
  | ($c | normalize($roots)) as $ran
  | .claims[] | select((.check | normalize($roots)) == $ran) | .id
' "$contract")
[ -n "$claim_ids" ] || exit 0

if [ "$(input_field .tool_input.run_in_background)" = true ] || matches 'background|backgroundTaskId' "$(input_field '.tool_response | tostring')"; then
  emit_context "$event_name" "proof: a check that runs in the background does not count. Run it in the foreground and wait for it to finish."
  exit 0
fi

if [ "$CWD_PHYSICAL" != "$ROOT_PHYSICAL" ]; then
  emit_context "$event_name" "proof: checks count only when run from the project root ($ROOT). Run it again from there."
  exit 0
fi

if [ "$result" = fail ]; then
  exit_code=$(input_field '.error | tostring | capture("Exit code (?<n>[0-9]+)").n')
  case "$exit_code" in 126|127) result=error ;; esac
fi

lock_contract
record_check_files "$contract"
if [ -f "$CHECK_STARTED" ]; then
  untracked_hashes | awk -F'\t' 'FILENAME == ARGV[1] { before[$0] = 1; next } !($0 in before) { print $2 }' "$CHECK_STARTED" - >> "$OUTPUTS"
  rm -f "$CHECK_STARTED"
fi

split_hashes "$(snapshot)"
recorded_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
while IFS= read -r id; do
  [ -n "$id" ] || continue
  "$JQ" -nc --arg claim "$id" --arg check "$command_text" --arg result "$result" --arg code "$CODE_HASH" --arg tests "$TEST_HASH" --arg source "$SOURCE_HASH" --arg at "$recorded_at" \
    '{claim: $claim, check: $check, result: $result, code_hash: $code, test_hash: $tests, source_hash: $source, at: $at}' >> "$EVIDENCE"
done <<< "$claim_ids"

claims_text=$(paste -sd, - <<< "$claim_ids" | sed 's/,/, /g')
case "$result" in
  pass)
    emit_context "$event_name" "proof: recorded a pass for $claims_text on the current code. Any later code edit makes it stale."
    ;;
  error)
    emit_context "$event_name" "proof: the check for $claims_text could not start (exit $exit_code), so it counts as neither a pass nor a failure. Fix the command, or make sure the program it runs exists."
    ;;
  fail)
    repeated=$("$JQ" -rs --arg ids "$claim_ids" '
      ($ids | split("\n") | map(select(length > 0))) as $wanted
      | [$wanted[] as $id | [.[] | select(.claim == $id) | .result] | (.[-2:] == ["fail", "fail"])] | any
    ' "$EVIDENCE")
    note="proof: recorded a failure for $claims_text."
    [ "$repeated" = true ] && note="$note This check has now failed twice in a row. Stop guessing: read the failing code path, add one probe that shows the actual values, or ask the user."
    emit_context "$event_name" "$note"
    ;;
esac
