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

case "$(lower "$rel")" in
  .proof/contract.json)
    is_locked || exit 0
    candidate="$STATE/candidate.$$"
    proposed_content "$rel" > "$candidate"
    problems=$(contract_errors_of "$candidate"; [ -s "$candidate" ] && "$JQ" -e . "$candidate" >/dev/null 2>&1 && extension_errors "$candidate")
    rm -f "$candidate"
    [ -z "$problems" ] && exit 0
    deny_tool "The contract is locked because a check program has run. You may only add claims or unverified items; existing claims, the goal, the kind and allowed_test_changes stay as they were.
$problems"
    ;;
  .proof/*)
    deny_tool "Only .proof/contract.json may be written under .proof/."
    ;;
esac

new_text=$(input_field '.tool_input.content // .tool_input.new_string // .tool_input.new_source // ([.tool_input.edits[]?.new_string] | join("\n"))')

if { is_test_path "$rel" || is_test_config "$rel"; } && matches "$SKIP_MARKER_RE" "$new_text"; then
  deny_tool "Skipping, focusing or marking a test as expected-to-fail is not allowed. Fix the code, or name the claim as unverified."
fi

if is_protected "$rel" && ! allowed_test_change "$rel"; then
  deny_tool "$rel is an existing test, a test setting, or a script a check runs, so it is read-only. Put new tests in a new file and make the code satisfy the existing ones. If this file truly must change, list it in allowed_test_changes with a reason before any check runs. A failing test is evidence about the code (craft-proof:testing-best-practices)."
fi

if ! is_doc_path "$rel" && ! contract_valid_file "$(active_contract)"; then
  deny_tool "No valid contract yet, so code edits are blocked.
$(contract_errors_of "$(active_contract)")
$CONTRACT_GUIDE"
fi

exit 0
