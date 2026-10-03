#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
is_git || exit 0

result=${1:-}
case "$result" in pass|fail) ;; *) exit 0 ;; esac
contract_valid || exit 0

command_text=$(input_field .tool_input.command)
claim_ids=$("$JQ" -r --arg c "$command_text" --arg root "$ROOT" --arg physical "$ROOT_PHYSICAL" --arg cwd "$INPUT_CWD" "$normalize_command_jq"'
  [$root, $physical, $cwd] as $roots
  | ($c | normalize($roots)) as $ran
  | .claims[] | select((.check | normalize($roots)) == $ran) | .id
' "$CONTRACT")
[ -n "$claim_ids" ] || exit 0

[ -f "$LOCK" ] || file_hash "$CONTRACT" > "$LOCK"
current=$(code_hash)
recorded_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
event_name=PostToolUse
[ "$result" = fail ] && event_name=PostToolUseFailure

for id in $claim_ids; do
  "$JQ" -nc --arg claim "$id" --arg check "$command_text" --arg result "$result" --arg hash "$current" --arg at "$recorded_at" \
    '{claim: $claim, check: $check, result: $result, code_hash: $hash, at: $at}' >> "$EVIDENCE"
done

if [ "$result" = pass ]; then
  emit_context "$event_name" "proof: recorded a pass for $(printf '%s' "$claim_ids" | tr '\n' ' ')on the current code. Any later code edit makes it stale."
  exit 0
fi

repeated=$("$JQ" -rs --arg ids "$claim_ids" '
  ($ids | split("\n") | map(select(length > 0))) as $wanted
  | [$wanted[] as $id | [.[] | select(.claim == $id) | .result] | (.[-2:] == ["fail", "fail"])] | any
' "$EVIDENCE")
note="proof: recorded a failure for $(printf '%s' "$claim_ids" | tr '\n' ' ')."
if [ "$repeated" = true ]; then
  note="$note This check has now failed twice in a row. Stop guessing: read the failing code path, add one probe that shows the actual values, or ask the user."
fi
emit_context "$event_name" "$note"
