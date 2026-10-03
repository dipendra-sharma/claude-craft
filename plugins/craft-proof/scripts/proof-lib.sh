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
DOC_PATH_RE='\.(md|mdx|txt|rst|adoc|csv|tsv)$'
IGNORED_PATH_RE='(^|/)\.claude/|^\.proof/'
SKIP_MARKER_RE='(unittest\.skip|skipTest\(|expectedFailure|mark\.(skip|xfail)|\.skip\(|\.only\(|\bxit[ (]|\bxtest\(|\bxdescribe\(|\bfit\(|\bfdescribe\(|@Ignore|@Disabled|t\.Skip|SkipNow\(|XCTSkip|skip:[[:space:]]*(true|["'"'"']))'
CHECK_KINDS='bugfix|feature|change|deliverable'
JUDGE_SECONDS=90

CONTRACT_GUIDE='Write .proof/contract.json with the Write tool before changing code or writing a deliverable (a document, plan, report, data file, or any file outside a git repository). Shape:
{
  "goal": "what the user will observe when this is done",
  "kind": "bugfix | feature | change | deliverable",
  "claims": [
    {"id": "C1", "claim": "user-visible behavior", "check": "shell command that exits 0 only when the claim holds", "fail_first": true},
    {"id": "C2", "claim": "a fact the work relies on", "source": {"location": "https://... or a file path", "quote": "exact words from that source"}},
    {"id": "C3", "claim": "a number in the work", "calc": {"expression": "4200 * 12", "result": "50400"}},
    {"id": "C4", "claim": "what the deliverable contains", "file": {"path": "docs/plan.md", "contains": ["^## Risks", "rollback"]}},
    {"id": "C5", "claim": "a quality only judgement can check", "rubric": {"target": "docs/plan.md", "criteria": "PASS if ... FAIL if ..."}}
  ],
  "allowed_test_changes": [{"path": "tests/test_x.py", "reason": "why this existing test or test setting must change"}],
  "unverified": ["anything you cannot check here, and why"]
}
Each claim carries exactly one of check, source, calc, file or rubric. A rubric target is a file path or "reply" for your final answer.
Rules:
- Every deliverable you write must be named by a file, rubric or source claim.
- Write each check relative to the project root, with no leading cd, and run it from the project root with exactly that text. Checks may chain with && but may not use |, || or ;.
- A bugfix needs a check claim with fail_first true. Its check must be seen failing on the unfixed code and passing after the fix, with the same test files both times. "Command not found" does not count as failing.
- Source, calc, file and rubric claims are re-checked on the final content when you finish.
- The contract locks once any check program runs or you first try to finish. After that, you may only add claims or unverified items.
- Existing test files, test settings and the scripts your checks run are read-only, unless listed in allowed_test_changes before the lock. Put new tests in new files.
- Every unverified item is shown to the user when you finish.
- With 3 or more claims, keep a todo list before editing: one TaskCreate per claim, with the claim id in the subject (for example "C2: ..."). An item can be marked completed only when the claims it names are proven, and open items block finishing unless their description has a line "Blocked: <reason>".

Skills: load craft-proof:contract for the full workflow. For code, craft-proof:testing-best-practices before writing the test behind a claim and craft-proof:coding-best-practices before writing the code. For documents and analysis, craft-proof:product-spec for specs, craft-proof:decision-partner for recommendations, and craft-proof:calculator for any number.'

input_field() {
  "$JQ" -r "$1 // empty" <<< "$PROOF_INPUT"
}

physical_dir() {
  (cd "$1" 2>/dev/null && pwd -P)
}

INPUT_CWD=$(input_field .cwd)
[ -n "$INPUT_CWD" ] || INPUT_CWD=$PWD
SESSION_BASE=${CLAUDE_PROJECT_DIR:-$INPUT_CWD}
IN_GIT=""
ROOT=$(git -C "$SESSION_BASE" rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$ROOT" ]; then IN_GIT=yes; else ROOT=$SESSION_BASE; fi
ROOT_PHYSICAL=$(physical_dir "$ROOT")
CWD_PHYSICAL=$(physical_dir "$INPUT_CWD")

proof_active() {
  [ -n "$ROOT_PHYSICAL" ] || return 1
  [ -n "$IN_GIT" ] && return 0
  [ "$ROOT_PHYSICAL" != "/" ] && [ "$ROOT_PHYSICAL" != "$(physical_dir ~)" ]
}

PLUGIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE_BASE=""
STATE=""
if proof_active; then
  if [ -n "$IN_GIT" ]; then
    STATE_BASE="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/craft-proof"
    STATE="$STATE_BASE/$(printf '%s' "$ROOT_PHYSICAL" | sha256 | cut -c1-16)"
  else
    STATE_BASE="$ROOT_PHYSICAL/.proof/state"
    STATE="$STATE_BASE"
  fi
  mkdir -p "$STATE"
fi
WORK_CONTRACT="$ROOT/.proof/contract.json"
ACCEPTED="$STATE/contract.json"
BASELINE="$STATE/baseline.tsv"
EVIDENCE="$STATE/evidence.jsonl"
CHECK_FILES="$STATE/check-files.tsv"
OUTPUTS="$STATE/outputs.txt"
DELIVERABLES="$STATE/deliverables.txt"
JUDGED="$STATE/judged.tsv"
CHECK_STARTED="$STATE/check-started"
GATE_MEMORY="$STATE/gate.last"
OUTCOME="$STATE/outcome"

is_git() {
  [ -n "$IN_GIT" ]
}

matches() {
  "$GREP" -Eq "$1" <<< "$2"
}

is_test_path() { matches "$TEST_PATH_RE" "$1"; }
is_test_config() { matches "$TEST_CONFIG_RE" "$1"; }
is_doc_path() { matches "$DOC_PATH_RE" "$1"; }
is_ignored_path() { matches "$IGNORED_PATH_RE" "$1"; }

is_deliverable() {
  is_ignored_path "$1" && return 1
  is_git || return 0
  is_doc_path "$1"
}

awk_re() {
  printf '%s' "${1//\//\\/}"
}

hash_file() {
  if is_git; then git -C "$ROOT" hash-object -- "$1"; else sha256 "$ROOT/$1"; fi
}

touched_deliverables() {
  [ -f "$DELIVERABLES" ] || return 0
  sort -u "$DELIVERABLES" | while IFS= read -r path; do
    [ -f "$ROOT/$path" ] && printf '%s\n' "$path"
  done
  return 0
}

snapshot() {
  if ! is_git; then
    touched_deliverables | while IFS= read -r path; do printf '%s\t%s\n' "$(hash_file "$path")" "$path"; done
    return 0
  fi
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
  is_git || return 0
  awk -F'\t' '
    FILENAME == ARGV[1] { base[$2] = $1; next }
    { seen[$2] = 1; if (base[$2] != $1) print $2 }
    END { for (p in base) if (!(p in seen)) print p }
  ' "$BASELINE" - <<< "$snap" | sort -u
}

protected_entries() {
  if is_git && [ -f "$BASELINE" ]; then
    awk -F'\t' '$2 ~ /'"$(awk_re "$TEST_PATH_RE")"'/ || $2 ~ /'"$(awk_re "$TEST_CONFIG_RE")"'/' "$BASELINE"
  fi
  if [ -f "$CHECK_FILES" ]; then cat "$CHECK_FILES"; fi
  return 0
}

is_protected() {
  protected_entries | awk -F'\t' -v p="$1" 'tolower($2) == tolower(p) { found = 1 } END { exit !found }'
}

current_hash_of() {
  [ -f "$ROOT/$1" ] && hash_file "$1"
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
    def evidence: [("check", "source", "calc", "file", "rubric") as $k | select(has($k)) | $k];
    def evidence_errors:
      if .check != null then
        (if (.check | blank) then "Claim \(.id) has an empty \"check\"."
         elif (.check | test("\\|\\||\\||;")) then "Claim \(.id) check \"\(.check)\" uses |, || or ;, which can hide a failure. Use one command, or chain commands with &&."
         elif (.check | gsub("^\\s+|\\s+$"; "") | test("^(true|:|exit( 0)?|echo)( |$)")) then "Claim \(.id) check \"\(.check)\" cannot fail, so it proves nothing."
         else empty end)
      elif .source != null then
        (if (.source.location | blank) or (.source.quote | blank) then "Claim \(.id) source needs a \"location\" and a \"quote\"."
         elif (.source.quote | length) < 12 then "Claim \(.id) quote is too short to prove anything; copy a full phrase from the source."
         else empty end)
      elif .calc != null then
        (if (.calc.expression | blank) or ((.calc.result | tostring) | blank) then "Claim \(.id) calc needs an \"expression\" and a \"result\"." else empty end)
      elif .file != null then
        (if (.file.path | blank) or ((.file.contains | type) != "array") or ((.file.contains | length) == 0) then "Claim \(.id) file needs a \"path\" and a non-empty \"contains\" list of patterns." else empty end)
      else
        (if (.rubric.target | blank) or (.rubric.criteria | blank) then "Claim \(.id) rubric needs a \"target\" (a file path or \"reply\") and \"criteria\"." else empty end)
      end;
    [
      (if (.goal | blank) then "\"goal\" is missing." else empty end),
      (if ((.kind // "") | test($kinds) | not) then "\"kind\" must be bugfix, feature, change or deliverable." else empty end),
      (if ((.claims | type) != "array") or ((.claims | length) == 0) then "\"claims\" must be a non-empty list." else empty end),
      (if ((.claims // []) | map(.id) | length) != ((.claims // []) | map(.id) | unique | length) then "Claim ids must be unique." else empty end),
      ((.claims // [])[] |
        (if (.id | blank) then "A claim has no \"id\"." else empty end),
        (if (.claim | blank) then "Claim \(.id // "?") has no \"claim\" text." else empty end),
        (if (evidence | length) != 1 then "Claim \(.id // "?") needs exactly one of check, source, calc, file or rubric."
         else evidence_errors end),
        (if (.fail_first == true) and (.check == null) then "Claim \(.id) uses fail_first, which only applies to a check." else empty end)),
      (if (.kind == "bugfix") and (((.claims // []) | map(select(.fail_first == true and .check != null)) | length) == 0)
       then "A bugfix needs at least one check claim with \"fail_first\": true." else empty end),
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
        ($a.claims[] as $c | if ([$b.claims[]? | select(. == $c)] | length) == 0
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
    [$root, $physical] as $roots | .claims[]? | select(.check != null) | .check | normalize($roots) | program
  ' "$1" | sort -u
}

lock_contract() {
  is_locked && return 0
  contract_valid_file "$WORK_CONTRACT" || return 0
  cp "$WORK_CONTRACT" "$ACCEPTED"
  record_check_files "$ACCEPTED"
}

record_check_files() {
  local contract=$1 token
  "$JQ" -r --arg root "$ROOT" --arg physical "$ROOT_PHYSICAL" "$normalize_command_jq"'
    [$root, $physical] as $roots | .claims[]? | select(.check != null) | .check | normalize($roots) | split(" ")[] | select(startswith("-") | not)
  ' "$contract" | sed 's|^\./||' | sort -u | while IFS= read -r token; do
    [ -f "$ROOT/$token" ] || continue
    case "$token" in /*) continue ;; esac
    is_test_path "$token" && continue
    awk -F'\t' -v p="$token" '$2 == p { found = 1 } END { exit !found }' "$CHECK_FILES" 2>/dev/null && continue
    printf '%s\t%s\n' "$(hash_file "$token")" "$token" >> "$CHECK_FILES"
  done
}

untracked_hashes() {
  is_git || return 0
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
    .claims[] | select(.check != null) as $c
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

flatten_text() {
  sed -e 's/<[^>]*>/ /g' -e 's/&nbsp;/ /g' -e 's/&amp;/\&/g' -e 's/&quot;/"/g' -e "s/&#39;/'/g" -e 's/&lt;/</g' -e 's/&gt;/>/g' \
    | tr '\n\t\r' '   ' | tr -s ' ' | tr '[:upper:]' '[:lower:]'
}

read_location() {
  local location=$1
  case "$location" in
    http://*|https://*|file://*) curl -sSL --max-time 20 --max-filesize 20000000 -- "$location" 2>/dev/null ;;
    /*) cat -- "$location" 2>/dev/null ;;
    *) cat -- "$ROOT/$location" 2>/dev/null ;;
  esac
}

verify_source() {
  local location=$1 quote=$2 text wanted
  text=$(read_location "$location") || true
  [ -n "$text" ] || { printf 'could not open %s' "$location"; return 1; }
  wanted=$(flatten_text <<< "$quote" | sed 's/^ //; s/ $//')
  if "$GREP" -Fq -- "$wanted" <<< "$(flatten_text <<< "$text")"; then return 0; fi
  printf 'the quote was not found in %s' "$location"
  return 1
}

number_of() {
  sed -E 's/^approx\.? *//; s/[^0-9eE.+-]//g' <<< "$1"
}

verify_calc() {
  local expression=$1 expected=$2 actual want got
  if command -v qalc >/dev/null 2>&1; then
    actual=$(qalc -t -- "$expression" 2>/dev/null | tail -1)
  elif matches '^[0-9 .+*/()%^-]+$' "$expression"; then
    actual=$(printf 'scale=12; %s\n' "$expression" | bc -l 2>/dev/null)
  else
    printf 'this expression needs qalc, which is not installed'
    return 1
  fi
  [ -n "$actual" ] || { printf 'the expression could not be evaluated'; return 1; }
  want=$(number_of "$expected")
  got=$(number_of "$actual")
  if [ -n "$want" ] && [ -n "$got" ] && awk -v a="$got" -v b="$want" 'BEGIN { d = a - b; if (d < 0) d = -d; m = (b < 0 ? -b : b); if (m < 1) m = 1; exit !(d <= 1e-9 * m) }'; then
    return 0
  fi
  [ "$(lower "$(tr -d ' ' <<< "$actual")")" = "$(lower "$(tr -d ' ' <<< "$expected")")" ] && return 0
  printf 'it evaluates to %s, not %s' "$actual" "$expected"
  return 1
}

verify_file() {
  local path=$1 patterns=$2 pattern missing=""
  [ -f "$ROOT/$path" ] || { printf '%s does not exist' "$path"; return 1; }
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    "$GREP" -Eq -- "$pattern" "$ROOT/$path" || missing="$missing \"$pattern\""
  done <<< "$patterns"
  [ -z "$missing" ] && return 0
  printf '%s does not contain:%s' "$path" "$missing"
  return 1
}

judge() {
  local criteria=$1 content=$2 prompt raw
  command -v claude >/dev/null 2>&1 || { printf 'no judge is available (the claude command is not on the PATH)'; return 1; }
  prompt="You are a strict reviewer. Judge ONLY the content below against the criteria. Reply with one line of JSON and nothing else: {\"pass\": true or false, \"reason\": \"one sentence\"}.

Criteria:
$criteria

Content:
${content:0:40000}"
  raw=$(CLAUDE_CRAFT_RULES=off perl -e 'alarm shift; exec @ARGV' "$JUDGE_SECONDS" claude -p --model haiku --tools "" --no-session-persistence "$prompt" 2>/dev/null) || true
  raw=$("$GREP" -Eo '\{[^{}]*"pass"[^{}]*\}' <<< "$raw" | tail -1)
  [ -n "$raw" ] || { printf 'the judge gave no verdict'; return 1; }
  [ "$("$JQ" -r '.pass' <<< "$raw" 2>/dev/null)" = true ] && return 0
  printf '%s' "$("$JQ" -r '.reason // "the judge said it does not meet the criteria"' <<< "$raw" 2>/dev/null)"
  return 1
}

verify_rubric() {
  local target=$1 criteria=$2 reply=$3 content key cached verdict
  if [ "$target" = reply ]; then content=$reply; else
    [ -f "$ROOT/$target" ] || { printf '%s does not exist' "$target"; return 1; }
    content=$(cat "$ROOT/$target")
  fi
  key=$(sha256 <<< "$criteria
$content")
  cached=$(awk -F'\t' -v k="$key" '$1 == k { line = $0 } END { print line }' "$JUDGED" 2>/dev/null)
  if [ -n "$cached" ]; then
    verdict=$(cut -f2 <<< "$cached")
    [ "$verdict" = pass ] && return 0
    printf '%s' "$(cut -f3- <<< "$cached")"
    return 1
  fi
  if verdict=$(judge "$criteria" "$content"); then
    printf '%s\tpass\t\n' "$key" >> "$JUDGED"
    return 0
  fi
  printf '%s\tfail\t%s\n' "$key" "$verdict" >> "$JUDGED"
  printf '%s' "$verdict"
  return 1
}

deliverable_claims() {
  "$JQ" -c '.claims[] | select(.check == null)' "$1"
}

uncovered_deliverables() {
  local contract=$1 covered
  covered=$("$JQ" -r '.claims[] | (.file.path // .rubric.target // .source.location // empty)' "$contract" | sed 's|^\./||' | tr '[:upper:]' '[:lower:]')
  touched_deliverables | while IFS= read -r path; do
    "$GREP" -Fxq -- "$(lower "$path")" <<< "$covered" || printf '%s\n' "$path"
  done
  return 0
}

archive_task() {
  local dest="$STATE/archive/$(date +%Y%m%dT%H%M%S)-$$"
  mkdir -p "$dest"
  for name in contract.json evidence.jsonl check-files.tsv outputs.txt deliverables.txt judged.tsv gate.last outcome check-started; do
    [ -e "$STATE/$name" ] && mv "$STATE/$name" "$dest/"
  done
  [ -f "$WORK_CONTRACT" ] && mv "$WORK_CONTRACT" "$dest/work-contract.json"
  return 0
}

take_baseline() {
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

TASKS_NEEDED_AT=3

tasks_dir() {
  printf '%s/tasks/%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" "$1"
}

session_tasks() {
  local dir
  dir=$(tasks_dir "$1")
  if [[ ! "$1" =~ ^[A-Za-z0-9_-]+$ ]] || ! compgen -G "$dir/*.json" >/dev/null; then
    printf '[]'
    return 0
  fi
  "$JQ" -s 'sort_by(.id | tonumber? // 0)' "$dir"/*.json 2>/dev/null || printf '[]'
}

claims_named_in() {
  "$JQ" -r --arg text "$2" '
    def esc: gsub("(?<c>[.*+?^${}()|\\[\\]\\\\/])"; "\\\(.c)");
    .claims[] | .id as $id | select($text | test("(^|[^A-Za-z0-9_])" + ($id | esc) + "($|[^A-Za-z0-9_])")) | $id
  ' "$1"
}

claim_count() {
  "$JQ" -r '.claims | length' "$1"
}

claim_problem_now() {
  local contract=$1 id=$2 states=$3 claim state
  claim=$("$JQ" -c --arg id "$id" '.claims[] | select(.id == $id)' "$contract")
  if "$JQ" -e '.check != null' <<< "$claim" >/dev/null; then
    state=$(awk -F'\t' -v id="$id" '$1 == id { print $2 }' <<< "$states")
    [ "$state" = proven ] || { printf '%s is %s' "$id" "${state:-never-run}"; return 1; }
  elif "$JQ" -e '.source != null' <<< "$claim" >/dev/null; then
    verify_source "$("$JQ" -r '.source.location' <<< "$claim")" "$("$JQ" -r '.source.quote' <<< "$claim")" || return 1
  elif "$JQ" -e '.calc != null' <<< "$claim" >/dev/null; then
    verify_calc "$("$JQ" -r '.calc.expression' <<< "$claim")" "$("$JQ" -r '.calc.result | tostring' <<< "$claim")" || return 1
  elif "$JQ" -e '.file != null' <<< "$claim" >/dev/null; then
    verify_file "$("$JQ" -r '.file.path' <<< "$claim")" "$("$JQ" -r '.file.contains[]' <<< "$claim")" || return 1
  fi
  return 0
}
