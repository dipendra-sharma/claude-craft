#!/bin/bash

JQ=$(command -v jq || printf '/usr/bin/jq')
GREP=/usr/bin/grep
PROOF_INPUT=$(cat)

TEST_PATH_RE='(^|/)(tests?|__tests__|spec)/|(_test|\.test|_spec|\.spec)\.[A-Za-z0-9]+$|(^|/)test_[^/]*\.py$|\.snap$'
DOC_PATH_RE='\.(md|txt|rst)$'
SKIP_MARKER_RE='(unittest\.skip|pytest\.mark\.(skip|xfail)|\.skip\(|\bxit\(|\bxtest\(|\bxdescribe\(|@Ignore|@Disabled|t\.Skip\()'
TRIVIAL_CHECK_RE='^(true|:|exit 0|echo( |$))|\|\| *(true|:)|; *(true|:) *$'

CONTRACT_GUIDE='Write .proof/contract.json before changing code. Shape:
{
  "goal": "what the user will observe when this is done",
  "kind": "bugfix | feature | change",
  "claims": [
    {"id": "C1", "claim": "user-visible behavior", "check": "exact shell command that exits 0 only when the claim holds", "fail_first": true}
  ],
  "allowed_test_changes": [{"path": "tests/test_x.py", "reason": "why this existing test is wrong"}],
  "unverified": ["anything you cannot check here, and why"]
}
Rules: create the contract with the Write tool; write each check relative to the project folder, without a leading cd, and run it with exactly that text so the hooks record it; a bugfix needs a claim with fail_first true, and that check must be seen failing before the fix and passing after; the contract locks once any check has run; existing test files may gain new tests but their original lines cannot be changed or removed unless listed in allowed_test_changes; if "unverified" is not empty, your final reply must say which items are unverified.

Skills: load craft-proof:contract for the full contract workflow, craft-proof:testing-best-practices before writing the test behind a claim, and craft-proof:coding-best-practices before writing the code.'

input_field() {
  printf '%s' "$PROOF_INPUT" | "$JQ" -r "$1 // empty"
}

resolve_root() {
  local cwd
  cwd=$(input_field .cwd)
  [ -n "$cwd" ] || cwd=$PWD
  git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$cwd"
}

INPUT_CWD=$(input_field .cwd)
ROOT=$(resolve_root)
ROOT_PHYSICAL=$(cd "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
STATE="$ROOT/.proof"
BASELINE="$STATE/baseline.tsv"
BASELINE_COPIES="$STATE/baseline-files"
CONTRACT="$STATE/contract.json"
EVIDENCE="$STATE/evidence.jsonl"
LOCK="$STATE/contract.lock"
GATE_MEMORY="$STATE/gate.last"
OUTCOME="$STATE/outcome"

is_git() {
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

list_files() {
  if is_git; then
    git -C "$ROOT" ls-files -co --exclude-standard
  else
    (cd "$ROOT" && find . -type f -not -path './.git/*' -not -path './node_modules/*' -not -path './.proof/*' | sed 's|^\./||')
  fi | "$GREP" -v '^\.proof/' | sort -u
}

snapshot() {
  local paths
  paths=$(cd "$ROOT" && list_files | while IFS= read -r p; do [ -f "$p" ] && printf '%s\n' "$p"; done)
  [ -n "$paths" ] || return 0
  if is_git; then
    paste <(printf '%s\n' "$paths" | git -C "$ROOT" hash-object --stdin-paths) <(printf '%s\n' "$paths")
  else
    (cd "$ROOT" && printf '%s\n' "$paths" | tr '\n' '\0' | xargs -0 shasum -a 256 | awk '{h=$1; sub(/^[^ ]+  /, ""); print h "\t" $0}')
  fi
}

code_hash() {
  snapshot | shasum -a 256 | cut -d' ' -f1
}

file_hash() {
  shasum -a 256 "$1" | cut -d' ' -f1
}

changed_files() {
  local current="$STATE/current.tsv"
  snapshot > "$current"
  awk -F'\t' '
    FILENAME == ARGV[1] { base[$2] = $1; next }
    { seen[$2] = 1; if (base[$2] != $1) print $2 }
    END { for (p in base) if (!(p in seen)) print p }
  ' "$BASELINE" "$current" | sort -u
}

is_test_path() {
  "$GREP" -Eq "$TEST_PATH_RE" <<< "$1"
}

is_doc_path() {
  "$GREP" -Eq "$DOC_PATH_RE" <<< "$1"
}

in_baseline() {
  [ -f "$BASELINE" ] && awk -F'\t' -v p="$1" '$2 == p { found = 1 } END { exit !found }' "$BASELINE"
}

is_protected() {
  is_test_path "$1" && in_baseline "$1"
}

protected_files() {
  [ -f "$BASELINE" ] || return 0
  cut -f2 "$BASELINE" | "$GREP" -E "$TEST_PATH_RE"
}

save_protected_copies() {
  local protected
  while IFS= read -r protected; do
    [ -n "$protected" ] || continue
    mkdir -p "$BASELINE_COPIES/$(dirname "$protected")"
    cp "$ROOT/$protected" "$BASELINE_COPIES/$protected"
  done <<< "$(protected_files)"
}

drops_original_lines() {
  local protected=$1 candidate=$2
  [ -f "$candidate" ] || return 0
  local removed
  removed=$(diff "$BASELINE_COPIES/$protected" "$candidate" | "$GREP" "^<" || true)
  [ -n "$removed" ]
}

proposed_content() {
  local rel=$1
  printf '%s' "$PROOF_INPUT" | "$JQ" -j --rawfile current "$ROOT/$rel" '
    .tool_input as $t
    | def apply($old; $new): if ($old // "") == "" then . else split($old) | join($new // "") end;
    if $t.content != null then $t.content
    elif ($t.edits | type) == "array" then reduce $t.edits[] as $e ($current; apply($e.old_string; $e.new_string))
    else $current | apply($t.old_string; $t.new_string) end
  '
}

normalize_command_jq='
  def normalize($roots):
    gsub("^\\s+|\\s+$"; "") | gsub("\\s+"; " ")
    | reduce ($roots | map(select(length > 1)) | unique | sort_by(-length))[] as $r (.;
        reduce ("cd \($r) && ", "cd \($r)/ && ", "cd \"\($r)\" && ", "cd '"'"'\($r)'"'"' && ") as $prefix (.;
          if startswith($prefix) then .[($prefix | length):] else . end)
        | split($r + "/") | join("./"));
'

rel_path() {
  local abs=$1 dir base physical
  case "$abs" in /*) ;; *) abs="$ROOT/$abs" ;; esac
  dir=$(dirname "$abs")
  base=$(basename "$abs")
  physical=$(cd "$dir" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$base" || printf '%s' "$abs")
  case "$physical" in "$ROOT_PHYSICAL"/*) printf '%s\n' "${physical#"$ROOT_PHYSICAL"/}"; return 0 ;; esac
  case "$abs" in "$ROOT"/*) printf '%s\n' "${abs#"$ROOT"/}"; return 0 ;; esac
  return 1
}

contract_errors() {
  [ -f "$CONTRACT" ] || { printf 'No contract at .proof/contract.json.\n'; return 0; }
  "$JQ" -e . "$CONTRACT" >/dev/null 2>&1 || { printf '.proof/contract.json is not valid JSON.\n'; return 0; }
  "$JQ" -r --arg trivial "$TRIVIAL_CHECK_RE" '
    def blank: (type != "string") or (gsub("^\\s+|\\s+$"; "") == "");
    [
      (if (.goal | blank) then "\"goal\" is missing." else empty end),
      (if ((.claims | type) != "array") or ((.claims | length) == 0) then "\"claims\" must be a non-empty list." else empty end),
      ((.claims // [])[] |
        (if (.id | blank) then "A claim has no \"id\"." else empty end),
        (if (.claim | blank) then "Claim \(.id // "?") has no \"claim\" text." else empty end),
        (if (.check | blank) then "Claim \(.id // "?") has no \"check\" command."
         elif (.check | gsub("^\\s+|\\s+$"; "") | test($trivial)) then "Claim \(.id) check \"\(.check)\" cannot fail, so it proves nothing."
         else empty end)),
      (if (.kind == "bugfix") and (((.claims // []) | map(select(.fail_first == true)) | length) == 0)
       then "A bugfix needs at least one claim with \"fail_first\": true." else empty end),
      (if (.unverified != null) and ((.unverified | type) != "array") then "\"unverified\" must be a list of strings." else empty end),
      ((.allowed_test_changes // [])[] | select((.path | blank) or (.reason | blank)) | "Each allowed_test_changes entry needs a \"path\" and a \"reason\".")
    ] | .[]
  ' "$CONTRACT"
}

contract_valid() {
  [ -f "$CONTRACT" ] && [ -z "$(contract_errors)" ]
}

allowed_test_change() {
  [ -f "$CONTRACT" ] && "$JQ" -e --arg p "$1" '(.allowed_test_changes // []) | any(.path == $p)' "$CONTRACT" >/dev/null 2>&1
}

claim_states() {
  [ -f "$EVIDENCE" ] || : > "$EVIDENCE"
  "$JQ" -r --slurpfile ev "$EVIDENCE" --arg h "$(code_hash)" '
    .claims[] as $c
    | ($ev | map(select(.claim == $c.id))) as $runs
    | ($runs | last) as $last
    | if $last == null then [$c.id, "never-run", $c.check]
      elif $last.result != "pass" then [$c.id, "failing", $c.check]
      elif $last.code_hash != $h then [$c.id, "stale", $c.check]
      elif ($c.fail_first == true) and (($runs | map(.result) | index("fail")) == null) then [$c.id, "needs-red", $c.check]
      else [$c.id, "proven", $c.check] end
    | @tsv
  ' "$CONTRACT"
}

emit_context() {
  "$JQ" -n --arg e "$1" --arg c "$2" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $c}}'
}

deny_tool() {
  "$JQ" -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}
