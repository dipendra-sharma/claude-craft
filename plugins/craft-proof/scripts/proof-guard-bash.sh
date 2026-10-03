#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
is_git || exit 0

WRITE_OP_RE='>|\btee\b|\bsed\b[^|;&]*-[a-zA-Z]*i|\bperl\b[^|;&]*-[a-zA-Z]*i|\bmv\b|\bcp\b|\brm\b|\btruncate\b|\bdd\b|\bln\b|\bchmod\b|\bgit +(checkout|restore|rm|mv|reset|stash|apply|am|clean)\b|\bpython3?\b[^|;&]*-c'

command_text=$(input_field .tool_input.command)
[ -n "$command_text" ] || exit 0
[[ "$command_text" =~ ^[[:space:]]*CLAUDE_CRAFT_RULES=off[[:space:]] ]] && exit 0

unquoted=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<< "$command_text")
operations=$(sed -E 's/[0-9]*>&[0-9]+//g; s/[0-9]*> *\/dev\/null//g' <<< "$unquoted")
lowered=$(lower "$command_text")

writes() {
  matches "$WRITE_OP_RE" "$operations"
}

mentions_harness() {
  local marker
  for marker in "$PLUGIN_DIR" "$STATE_BASE" ".git/craft-proof" "claude_plugin_"; do
    [ -n "$marker" ] || continue
    case "$lowered" in *"$(lower "$marker")"*) return 0 ;; esac
  done
  matches 'proof-[a-z-]+\.sh' "$lowered"
}

if mentions_harness; then
  deny_tool "The proof plugin's own scripts and records are off limits to shell commands. Proof is recorded only when you run a contract check."
fi

if [[ "$command_text" == *--no-verify* ]]; then
  deny_tool "Skipping git hooks with --no-verify is not allowed."
fi

if [[ "$lowered" == *".proof"* ]] && writes; then
  deny_tool "Shell commands may read .proof/ but not change it. Write .proof/contract.json with the Write tool."
fi

if writes; then
  protected_list="$STATE/protected.$$"
  protected_entries | cut -f2 | sort -u > "$protected_list"
  hit=$("$GREP" -F -o -f "$protected_list" <<< "$command_text" | head -1)
  rm -f "$protected_list"
  if [ -n "$hit" ] && ! allowed_test_change "$hit"; then
    deny_tool "This command looks like it changes $hit, which is read-only during this task (an existing test, a test setting, or a script a check runs). Put new tests in a new file. If you only meant to read or run it, drop the redirect or file operation on that path."
  fi
fi

contract=$(active_contract)
if contract_valid_file "$contract"; then
  words=$("$JQ" -rn --arg c "$command_text" --arg root "$ROOT" --arg physical "$ROOT_PHYSICAL" --arg cwd "$CWD_PHYSICAL" --arg given "$INPUT_CWD" "$normalize_command_jq"'
    $c | normalize([$root, $physical, $cwd, $given]) | [scan("[^ ;|&()<>]+")] | map(sub("^\\./"; "")) | .[]')
  while IFS= read -r program; do
    [ -n "$program" ] || continue
    if "$GREP" -Fxq -- "${program#./}" <<< "$words"; then
      lock_contract
      untracked_hashes > "$CHECK_STARTED"
      break
    fi
  done <<< "$(check_programs "$contract")"
fi

exit 0
