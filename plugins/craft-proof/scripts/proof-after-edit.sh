#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
is_git || exit 0

target=$(input_field '.tool_input.file_path // .tool_input.notebook_path')
[ -n "$target" ] || exit 0
rel=$(rel_path "$target") || exit 0
[ "$rel" = ".proof/contract.json" ] || exit 0

problems=$(contract_errors)
if [ -n "$problems" ]; then
  "$JQ" -n --arg r "The contract was saved but is not usable yet:
$problems
Fix .proof/contract.json before editing code." '{decision: "block", reason: $r}'
  exit 0
fi

claim_list=$("$JQ" -r '.claims[] | "- \(.id): run exactly `\(.check)`" + (if .fail_first == true then " (must be seen failing before the fix, then passing)" else "" end)' "$CONTRACT")
emit_context PostToolUse "Contract accepted. It locks the first time any of these checks runs:
$claim_list
Write each test with craft-proof:testing-best-practices and the code with craft-proof:coding-best-practices."
