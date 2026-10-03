#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
is_git || exit 0

WRITE_OP_RE='>|\btee\b|\bsed\b[^|;&]*-i|\bperl\b[^|;&]*-i|\bmv\b|\bcp\b|\brm\b|\btruncate\b|\bdd\b|\bln\b|\bchmod\b|\bgit +(checkout|restore|rm|mv|reset|stash)\b|\bpython3?\b[^|;&]*-c'

command_text=$(input_field .tool_input.command)
[ -n "$command_text" ] || exit 0
[[ "$command_text" =~ ^[[:space:]]*CLAUDE_CRAFT_RULES=off[[:space:]] ]] && exit 0
without_harmless_redirects=$(printf '%s' "$command_text" | sed -E 's/[0-9]*>&[0-9]+//g; s/[0-9]*> *\/dev\/null//g')

writes() {
  "$GREP" -Eq "$WRITE_OP_RE" <<< "$without_harmless_redirects"
}

mentions() {
  "$GREP" -Fq -- "$1" <<< "$without_harmless_redirects"
}

if "$GREP" -Eq -- "--no-verify" <<< "$command_text"; then
  deny_tool "Skipping git hooks with --no-verify is not allowed."
fi

if mentions ".proof" && writes; then
  deny_tool "Shell commands may read .proof/ but not change it. Create or fix .proof/contract.json with the Write tool. Proof is recorded by the hooks when you run a contract check."
fi

if writes; then
  while IFS= read -r protected; do
    [ -n "$protected" ] || continue
    allowed_test_change "$protected" && continue
    if mentions "$protected" || mentions "$(basename "$protected")"; then
      deny_tool "This command looks like it changes $protected, an existing test that is protected. Use the Edit tool to add tests to it, and make the code satisfy its existing lines. If you only meant to read or run it, run the command without redirects or file operations on that path."
    fi
  done <<< "$(protected_files)"
fi

exit 0
