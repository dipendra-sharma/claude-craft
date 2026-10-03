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

case "$rel" in
  .proof/contract.json)
    [ -f "$LOCK" ] && deny_tool "The contract is locked because a check has already run against it. Do not change claims after seeing results. Finish the work, or say in your final reply which claim is unproven and why."
    exit 0
    ;;
  .proof/*)
    deny_tool "Files under .proof/ other than contract.json are written by the proof hooks only."
    ;;
esac

new_text=$(input_field ".tool_input.content // .tool_input.new_string // .tool_input.new_source // ([.tool_input.edits[]?.new_string] | join(\"\\n\"))")

if is_test_path "$rel" && "$GREP" -Eq "$SKIP_MARKER_RE" <<< "$new_text"; then
  deny_tool "Skipping, disabling or marking a test as expected-to-fail is not allowed. Fix the code, or record the claim as unverified in your final reply."
fi

if is_protected "$rel" && ! allowed_test_change "$rel"; then
  candidate="$STATE/proposed.tmp"
  proposed_content "$rel" > "$candidate"
  if drops_original_lines "$rel" "$candidate"; then
    deny_tool "$rel is an existing test. You may add new tests to it, but its original lines cannot be changed or removed. Make the code satisfy them. If an existing test is truly wrong, declare it in allowed_test_changes with a reason before any check runs. A failing test is evidence about the code (craft-proof:testing-best-practices)."
  fi
fi

if ! is_doc_path "$rel" && ! contract_valid; then
  deny_tool "No valid contract yet, so code edits are blocked.
$(contract_errors)
$CONTRACT_GUIDE"
fi

exit 0
