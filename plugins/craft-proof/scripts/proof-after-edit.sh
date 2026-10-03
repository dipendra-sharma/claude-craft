#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
proof_active || exit 0

target=$(input_field '.tool_input.file_path // .tool_input.notebook_path')
[ -n "$target" ] || exit 0
rel=$(rel_path "$target") || exit 0

if [ "$(lower "$rel")" != ".proof/contract.json" ]; then
  is_deliverable "$rel" && printf '%s\n' "$rel" >> "$DELIVERABLES"
  exit 0
fi

problems=$(contract_errors_of "$WORK_CONTRACT")
if [ -z "$problems" ] && is_locked; then
  problems=$(extension_errors "$WORK_CONTRACT")
fi
if [ -n "$problems" ]; then
  "$JQ" -n --arg r "The contract was saved but is not usable:
$problems
Fix .proof/contract.json before going on." '{decision: "block", reason: $r}'
  exit 0
fi

is_locked && record_check_files "$WORK_CONTRACT"
claim_list=$("$JQ" -r '.claims[] | "- \(.id): " + (
  if .check != null then "run exactly `\(.check)` from the project root" + (if .fail_first == true then " (must be seen failing on the unfixed code, then passing, with the same test files)" else "" end)
  elif .source != null then "the quote is re-checked in \(.source.location) when you finish"
  elif .calc != null then "\(.calc.expression) is recomputed and must equal \(.calc.result)"
  elif .file != null then "\(.file.path) must contain \(.file.contains | join(", "))"
  else "a judge reads \(.rubric.target) against the rubric when you finish" end)' "$WORK_CONTRACT")
emit_context PostToolUse "Contract accepted. It locks the first time a check program runs or you try to finish:
$claim_list
For code, write each test with craft-proof:testing-best-practices and the code with craft-proof:coding-best-practices. For numbers, use craft-proof:calculator."
