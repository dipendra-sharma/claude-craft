#!/bin/bash

JQ=$(command -v jq)
if [ -x /usr/bin/grep ]; then GREP=/usr/bin/grep; else GREP=$(command -v grep); fi
if command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$@" | cut -d' ' -f1; }
else
  sha256() { sha256sum "$@" | cut -d' ' -f1; }
fi
PROOF_INPUT=$(cat)

TEST_PATH_RE='(^|/)(tests?|specs?|__tests__|__snapshots__|goldens?|[A-Za-z]*Tests|[a-z]+Test|[A-Za-z0-9]+\.Tests?)/|(_test|\.test|_spec|\.spec)\.[A-Za-z0-9]+$|(^|/)test_[^/]*\.py$|(Test|Tests|Spec)\.(kt|kts|java|swift|scala|groovy|cs|m)$|\.snap$'
TEST_CONFIG_RE='(^|/)(pytest\.ini|tox\.ini|setup\.cfg|conftest\.py|jest\.config\.[a-z]+|vitest\.config\.[a-z]+|karma\.conf\.[a-z]+|playwright\.config\.[a-z]+|cypress\.config\.[a-z]+|\.mocharc[^/]*|phpunit\.xml(\.dist)?|analysis_options\.yaml|dart_test\.yaml|\.rspec|\.gitlab-ci\.yml)$|(^|/)\.github/workflows/|(^|/)\.circleci/'
DOC_PATH_RE='\.(md|mdx|txt|rst|adoc)$'
SKIP_MARKER_RE='(unittest\.skip|skipTest\(|expectedFailure|mark\.(skip|xfail)|\.skip\(|\.only\(|\bxit[ (]|\bxtest\(|\bxdescribe\(|\bfit\(|\bfdescribe\(|@Ignore|@Disabled|t\.Skip|SkipNow\(|XCTSkip|skip:[[:space:]]*(true|["'"'"']))'
CHECK_KINDS='bugfix|feature|change'

CONTRACT_GUIDE='Write .proof/contract.json with the Write tool before changing code. Shape:
{
  "goal": "what the user will observe when this is done",
  "kind": "bugfix | feature | change",
  "claims": [
    {"id": "C1", "claim": "user-visible behavior", "check": "exact shell command that exits 0 only when the claim holds", "fail_first": true}
  ],
  "allowed_test_changes": [{"path": "tests/test_x.py", "reason": "why this existing test or test setting must change"}],
  "unverified": ["anything you cannot check here, and why"]
}
Rules:
- Write each check relative to the project root, with no leading cd, and run it from the project root with exactly that text. Checks may chain with && but may not use |, || or ;.
- A bugfix needs a claim with fail_first true. Its check must be seen failing on the unfixed code and passing after the fix, with the same test files both times. "Command not found" does not count as failing.
- The contract locks once any check program runs. After that, you may only add claims or unverified items.
- Existing test files, test settings and the scripts your checks run are read-only, unless listed in allowed_test_changes before the lock. Put new tests in new files.
- Every unverified item is shown to the user when you finish.

Skills: load craft-proof:contract for the full contract workflow, craft-proof:testing-best-practices before writing the test behind a claim, and craft-proof:coding-best-practices before writing the code.'

input_field() {
  "$JQ" -r "$1 // empty" <<< "$PROOF_INPUT"
}

physical_dir() {
  (cd "$1" 2>/dev/null && pwd -P)
}

INPUT_CWD=$(input_field .cwd)
[ -n "$INPUT_CWD" ] || INPUT_CWD=$PWD
ROOT=$(git -C "${CLAUDE_PROJECT_DIR:-$INPUT_CWD}" rev-parse --show-toplevel 2>/dev/null || true)
ROOT_PHYSICAL=""
[ -n "$ROOT" ] && ROOT_PHYSICAL=$(physical_dir "$ROOT")
CWD_PHYSICAL=$(physical_dir "$INPUT_CWD")

PLUGIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE_BASE=""
STATE=""
if [ -n "$ROOT_PHYSICAL" ]; then
  STATE_BASE="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/craft-proof"
  STATE="$STATE_BASE/$(printf '%s' "$ROOT_PHYSICAL" | sha256 | cut -c1-16)"
  mkdir -p "$STATE"
fi
WORK_CONTRACT="$ROOT/.proof/contract.json"
ACCEPTED="$STATE/contract.json"
BASELINE="$STATE/baseline.tsv"
EVIDENCE="$STATE/evidence.jsonl"
CHECK_FILES="$STATE/check-files.tsv"
OUTPUTS="$STATE/outputs.txt"
CHECK_STARTED="$STATE/check-started"
GATE_MEMORY="$STATE/gate.last"
OUTCOME="$STATE/outcome"

is_git() {
  [ -n "$ROOT_PHYSICAL" ]
}

matches() {
  "$GREP" -Eq "$1" <<< "$2"
}

is_test_path() { matches "$TEST_PATH_RE" "$1"; }
is_test_config() { matches "$TEST_CONFIG_RE" "$1"; }
is_doc_path() { matches "$DOC_PATH_RE" "$1"; }

awk_re() {
  printf '%s' "${1//\//\\/}"
}

snapshot() {
  local changed_list="$STATE/changed.$$"
  [ -f "$OUTPUTS" ] || : > "$OUTPUTS"
  { git -C "$ROOT" diff --name-only; git -C "$ROOT" ls-files -o --exclude-standard; } | sort -u > "$changed_list"
  {
    git -C "$ROOT" ls-files -s | awk -F'\t' '
      FILENAME == ARGV[1] { skip[$0] = 1; next }
      { split($1, f, " "); if (!($2 in skip)) print f[2] "\t" $2 }
    ' "$changed_list" -
    (cd "$ROOT" && while IFS= read -r p; do [ -f "$p" ] && printf '%s\t%s\n' "$(git hash-object -- "$p")" "$p"; done < "$changed_list")
  } | awk -F'\t' '
      FILENAME == ARGV[1] { out[$0] = 1; next }
      $2 !~ /^\.proof\// && $2 !~ /'"$(awk_re "$DOC_PATH_RE")"'/ && !($2 in out)
    ' "$OUTPUTS" - | sort -t "$(printf '\t')" -k2,2 -u
  rm -f "$changed_list"
}

hash_of_lines() {
  sha256 <<< "$1"
}

split_hashes() {
  local snap=$1
  CODE_HASH=$(hash_of_lines "$snap")
  TEST_HASH=$(hash_of_lines "$(awk -F'\t' '$2 ~ /'"$(awk_re "$TEST_PATH_RE")"'/' <<< "$snap")")
  SOURCE_HASH=$(hash_of_lines "$(awk -F'\t' '$2 !~ /'"$(awk_re "$TEST_PATH_RE")"'/' <<< "$snap")")
}

changed_paths() {
  local snap=$1
  awk -F'\t' '
    FILENAME == ARGV[1] { base[$2] = $1; next }
    { seen[$2] = 1; if (base[$2] != $1) print $2 }
    END { for (p in base) if (!(p in seen)) print p }
  ' "$BASELINE" - <<< "$snap" | sort -u
}

protected_entries() {
  [ -f "$BASELINE" ] && awk -F'\t' '$2 ~ /'"$(awk_re "$TEST_PATH_RE")"'/ || $2 ~ /'"$(awk_re "$TEST_CONFIG_RE")"'/' "$BASELINE"
  if [ -f "$CHECK_FILES" ]; then cat "$CHECK_FILES"; fi
  return 0
}

is_protected() {
  protected_entries | awk -F'\t' -v p="$1" 'tolower($2) == tolower(p) { found = 1 } END { exit !found }'
}

current_hash_of() {
  [ -f "$ROOT/$1" ] && git -C "$ROOT" hash-object -- "$1"
}

normalize_path() {
  "$JQ" -rn --arg p "$1" '$p | split("/") | reduce .[] as $part ([]; if $part == ".." then .[:-1] elif $part == "." or $part == "" then . else . + [$part] end) | "/" + join("/")'
}

rel_path() {
  local abs=$1 normalized dir base physical lower_root lower_path
  case "$abs" in /*) ;; *) abs="$CWD_PHYSICAL/$abs" ;; esac
  normalized=$(normalize_path "$abs")
  dir=$(dirname "$normalized")
  base=$(basename "$normalized")
  physical=$(cd "$dir" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$base" || printf '%s' "$normalized")
  for candidate in "$physical" "$normalized"; do
    for prefix in "$ROOT_PHYSICAL" "$ROOT"; do
      lower_root=$(tr '[:upper:]' '[:lower:]' <<< "$prefix")
      lower_path=$(tr '[:upper:]' '[:lower:]' <<< "$candidate")
      case "$lower_path" in "$lower_root"/*) printf '%s\n' "${candidate:$((${#prefix} + 1))}"; return 0 ;; esac
    done
  done
  return 1
}

normalize_command_jq='
  def normalize($roots):
    gsub("^\\s+|\\s+$"; "") | gsub("\\s+"; " ")
    | reduce ($roots | map(select(length > 1)) | unique | sort_by(-length))[] as $r (.;
        reduce ("cd \($r) && ", "cd \($r)/ && ", "cd \"\($r)\" && ", "cd '"'"'\($r)'"'"' && ") as $prefix (.;
          if startswith($prefix) then .[($prefix | length):] else . end)
        | split($r + "/") | join("./"));
  def program:
    split(" ") | map(select(test("^[A-Za-z_][A-Za-z0-9_]*=") | not)) | (.[0] // "");
'

contract_errors_of() {
  local file=$1
  [ -f "$file" ] || { printf 'No contract at .proof/contract.json.\n'; return 0; }
  "$JQ" -e 'type == "object"' "$file" >/dev/null 2>&1 || { printf '.proof/contract.json is not a valid JSON object.\n'; return 0; }
  "$JQ" -r --arg kinds "^($CHECK_KINDS)$" '
    def blank: (type != "string") or (gsub("^\\s+|\\s+$"; "") == "");
    [
      (if (.goal | blank) then "\"goal\" is missing." else empty end),
      (if ((.kind // "") | test($kinds) | not) then "\"kind\" must be bugfix, feature or change." else empty end),
      (if ((.claims | type) != "array") or ((.claims | length) == 0) then "\"claims\" must be a non-empty list." else empty end),
      (if ((.claims // []) | map(.id) | length) != ((.claims // []) | map(.id) | unique | length) then "Claim ids must be unique." else empty end),
      ((.claims // [])[] |
        (if (.id | blank) then "A claim has no \"id\"." else empty end),
        (if (.claim | blank) then "Claim \(.id // "?") has no \"claim\" text." else empty end),
        (if (.check | blank) then "Claim \(.id // "?") has no \"check\" command."
         elif (.check | test("\\|\\||\\||;")) then "Claim \(.id) check \"\(.check)\" uses |, || or ;, which can hide a failure. Use one command, or chain commands with &&."
         elif (.check | gsub("^\\s+|\\s+$"; "") | test("^(true|:|exit( 0)?|echo)( |$)")) then "Claim \(.id) check \"\(.check)\" cannot fail, so it proves nothing."
         else empty end)),
      (if (.kind == "bugfix") and (((.claims // []) | map(select(.fail_first == true)) | length) == 0)
       then "A bugfix needs at least one claim with \"fail_first\": true." else empty end),
      (if (.unverified != null) and ((.unverified | type) != "array") then "\"unverified\" must be a list of strings." else empty end),
      ((.allowed_test_changes // [])[] | select((.path | blank) or (.reason | blank)) | "Each allowed_test_changes entry needs a \"path\" and a \"reason\".")
    ] | .[]
  ' "$file"
}

contract_valid_file() {
  [ -f "$1" ] && [ -z "$(contract_errors_of "$1")" ]
}

is_locked() {
  [ -f "$ACCEPTED" ]
}

extension_errors() {
  local proposed=$1
  "$JQ" -rn --slurpfile old "$ACCEPTED" --slurpfile new "$proposed" '
    $old[0] as $a | $new[0] as $b
    | [
        (if $a.goal != $b.goal or $a.kind != $b.kind then "The goal and kind cannot change after the lock." else empty end),
        ($a.claims[] as $c | if ([$b.claims[]? | select(.id == $c.id and .claim == $c.claim and .check == $c.check and .fail_first == $c.fail_first)] | length) == 0
          then "Claim \($c.id) was changed or removed after the lock." else empty end),
        (if ($a.allowed_test_changes // []) != ($b.allowed_test_changes // []) then "allowed_test_changes cannot change after the lock." else empty end),
        (if (($a.unverified // []) - ($b.unverified // [])) != [] then "Unverified items cannot be removed after the lock." else empty end)
      ] | .[]'
}

active_contract() {
  if ! is_locked; then
    printf '%s' "$WORK_CONTRACT"
  elif [ -f "$WORK_CONTRACT" ] && contract_valid_file "$WORK_CONTRACT" && [ -z "$(extension_errors "$WORK_CONTRACT")" ]; then
    printf '%s' "$WORK_CONTRACT"
  else
    printf '%s' "$ACCEPTED"
  fi
}

contract_tampered() {
  is_locked || return 1
  [ -f "$WORK_CONTRACT" ] || return 0
  ! contract_valid_file "$WORK_CONTRACT" && return 0
  [ -n "$(extension_errors "$WORK_CONTRACT")" ]
}

allowed_test_change() {
  local contract
  contract=$(active_contract)
  [ -f "$contract" ] && "$JQ" -e --arg p "$1" '(.allowed_test_changes // []) | any((.path | ascii_downcase) == ($p | ascii_downcase))' "$contract" >/dev/null 2>&1
}

check_programs() {
  "$JQ" -r --arg root "$ROOT" --arg physical "$ROOT_PHYSICAL" "$normalize_command_jq"'
    [$root, $physical] as $roots | .claims[]?.check | normalize($roots) | program
  ' "$1" | sort -u
}

lock_contract() {
  is_locked && return 0
  contract_valid_file "$WORK_CONTRACT" || return 0
  mkdir -p "$STATE"
  cp "$WORK_CONTRACT" "$ACCEPTED"
  record_check_files "$ACCEPTED"
}

record_check_files() {
  local contract=$1 token
  "$JQ" -r --arg root "$ROOT" --arg physical "$ROOT_PHYSICAL" "$normalize_command_jq"'
    [$root, $physical] as $roots | .claims[]?.check | normalize($roots) | split(" ")[] | select(startswith("-") | not)
  ' "$contract" | sed 's|^\./||' | sort -u | while IFS= read -r token; do
    [ -f "$ROOT/$token" ] || continue
    case "$token" in /*) continue ;; esac
    is_test_path "$token" && continue
    awk -F'\t' -v p="$token" '$2 == p { found = 1 } END { exit !found }' "$CHECK_FILES" 2>/dev/null && continue
    printf '%s\t%s\n' "$(git -C "$ROOT" hash-object -- "$token")" "$token" >> "$CHECK_FILES"
  done
}

untracked_hashes() {
  (cd "$ROOT" && git ls-files -o --exclude-standard | while IFS= read -r path; do
    [ -f "$path" ] && printf '%s\t%s\n' "$(git hash-object -- "$path")" "$path"
  done)
  return 0
}

claim_states() {
  local contract=$1 snap=$2
  split_hashes "$snap"
  [ -f "$EVIDENCE" ] || : > "$EVIDENCE"
  "$JQ" -r --slurpfile ev "$EVIDENCE" --arg h "$CODE_HASH" '
    .claims[] as $c
    | ($ev | map(select(.claim == $c.id))) as $runs
    | ($runs | map(select(.result == "pass" or .result == "fail")) | last) as $last
    | if $last == null then [$c.id, "never-run", $c.check]
      elif $last.result != "pass" then [$c.id, "failing", $c.check]
      elif $last.code_hash != $h then [$c.id, "stale", $c.check]
      elif ($c.fail_first == true) and (($runs | map(select(.result == "fail" and .test_hash == $last.test_hash and .source_hash != $last.source_hash)) | length) == 0) then [$c.id, "needs-red", $c.check]
      else [$c.id, "proven", $c.check] end
    | @tsv
  ' "$contract"
}

archive_task() {
  local dest="$STATE/archive/$(date +%Y%m%dT%H%M%S)-$$"
  mkdir -p "$dest"
  for name in contract.json evidence.jsonl check-files.tsv outputs.txt gate.last outcome check-started; do
    [ -e "$STATE/$name" ] && mv "$STATE/$name" "$dest/"
  done
  [ -f "$WORK_CONTRACT" ] && mv "$WORK_CONTRACT" "$dest/work-contract.json"
  return 0
}

take_baseline() {
  mkdir -p "$STATE"
  local tmp="$BASELINE.tmp.$$"
  snapshot > "$tmp" && mv "$tmp" "$BASELINE"
}

emit_context() {
  "$JQ" -n --arg e "$1" --arg c "$2" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $c}}'
}

deny_tool() {
  "$JQ" -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

proposed_content() {
  local rel=$1 current=""
  [ -f "$ROOT/$rel" ] && current=$(cat "$ROOT/$rel")
  "$JQ" -j --arg current "$current" '
    .tool_input as $t
    | def apply($old; $new): if ($old // "") == "" then . else split($old) | join($new // "") end;
    if $t.content != null then $t.content
    elif ($t.edits | type) == "array" then reduce $t.edits[] as $e ($current; apply($e.old_string; $e.new_string))
    else $current | apply($t.old_string; $t.new_string) end
  ' <<< "$PROOF_INPUT"
}

lower() {
  tr '[:upper:]' '[:lower:]' <<< "$1"
}
