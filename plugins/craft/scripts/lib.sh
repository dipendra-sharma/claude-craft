#!/bin/bash

CRAFT_SEP=$'\037'
CRAFT_ALLOW_TTL_SECONDS=1800

craft_rules_off() { [ "${CLAUDE_CRAFT_RULES:-on}" = "off" ]; }

require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  printf 'craft: jq is not installed, so the craft guards are not running. Install it: brew install jq\n' >&2
  exit 1
}

craft_allow_file() { printf '%s' "${CLAUDE_CRAFT_ALLOW_FILE:-/tmp/claude-craft-allow-$(id -u)}"; }

craft_is_allowed() {
  local file
  file=$(craft_allow_file)
  [ -f "$file" ] || return 1
  awk -F '\t' -v key="$1" -v now="$(date +%s)" -v ttl="$CRAFT_ALLOW_TTL_SECONDS" \
    '$2 == key && now - $1 <= ttl { found = 1 } END { exit !found }' "$file"
}

craft_consume_allow() {
  local file kept
  file=$(craft_allow_file)
  [ -f "$file" ] || return 0
  kept=$(awk -F '\t' -v key="$1" '$2 != key' "$file")
  if [ -n "$kept" ]; then printf '%s\n' "$kept" > "$file"; else : > "$file"; fi
}

shell_segments() {
  awk '
    BEGIN { SEP = "\037" }
    { src = (NR > 1) ? src "\n" $0 : $0 }
    END { lex(src) }

    function emit_tok() {
      if (intok) { line = line (ntok ? SEP : "") pre tok; ntok++; pre = "" }
      tok = ""; intok = 0
    }
    function emit_seg() { emit_tok(); if (ntok) print line; line = ""; ntok = 0; pre = "" }
    function push(s, b) { depth++; st[depth] = s; bt[depth] = b }
    function pop() { state = st[depth]; depth--; if (state == 2) intok = 1 }

    function skip_heredocs(s, i,   k, j, ln) {
      for (k = 1; k <= nhd; k++) {
        while (i < n) {
          j = index(substr(s, i + 1), "\n")
          if (j == 0) { ln = substr(s, i + 1); i = n } else { ln = substr(s, i + 1, j - 1); i += j }
          if (hdtab[k]) sub(/^\t+/, "", ln)
          if (ln == hddelim[k]) break
        }
      }
      nhd = 0
      return i
    }

    function read_heredoc(s, i,   tabs, d, c) {
      tabs = 0
      if (substr(s, i + 1, 1) == "-") { tabs = 1; i++ }
      while (substr(s, i + 1, 1) ~ /[ \t]/) i++
      d = ""
      while (i < n) {
        c = substr(s, i + 1, 1)
        if (c ~ /[ \t\n;|&<>()]/) break
        if (c != "\"" && c != "\047" && c != "\\") d = d c
        i++
      }
      nhd++; hddelim[nhd] = d; hdtab[nhd] = tabs
      return i
    }

    function lex(s,   i, c, nx, op) {
      n = length(s); state = 0; depth = 0; nhd = 0
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1); nx = substr(s, i + 1, 1)
        if (state == 1) { if (c == "\047") state = 0; else tok = tok c; continue }
        if (state == 2) {
          if (c == "\\" && index("$`\"\\\n", nx)) { if (nx != "\n") tok = tok nx; i++; continue }
          if (c == "\"") { state = 0; continue }
          if (c == "$" && nx == "(") { emit_seg(); push(2, 0); state = 0; i++; continue }
          if (c == "`") { emit_seg(); push(2, 1); state = 0; continue }
          tok = tok c; continue
        }
        if (c == "\\") { if (nx != "\n") { tok = tok nx; intok = 1 }; i++; continue }
        if (c == "\047") { state = 1; intok = 1; continue }
        if (c == "\"") { state = 2; intok = 1; continue }
        if (c == " " || c == "\t") { emit_tok(); continue }
        if (c == "\n") { emit_seg(); if (nhd) i = skip_heredocs(s, i); continue }
        if (c == "#" && !intok) { while (i < n && substr(s, i + 1, 1) != "\n") i++; continue }
        if (c == "<" || c == ">" || (c == "&" && nx == ">")) {
          if (intok && tok ~ /^[0-9]+$/) { tok = ""; intok = 0 } else emit_tok()
          op = c
          while (i < n && index("<>&|", substr(s, i + 1, 1))) { i++; op = op substr(s, i, 1) }
          if (op == "<<") { i = read_heredoc(s, i); continue }
          if (op ~ /[<>]&$/) { pre = "&"; continue }
          pre = index(op, ">") ? ">" : "<"
          continue
        }
        if (c == ";" || c == "|" || c == "&") { emit_seg(); continue }
        if (c == "$" && nx == "(") { emit_seg(); push(0, 0); i++; continue }
        if (c == "(") { emit_seg(); push(0, 0); continue }
        if (c == ")") { emit_seg(); if (depth) pop(); continue }
        if (c == "`") { emit_seg(); if (depth && bt[depth]) pop(); else push(0, 1); continue }
        tok = tok c; intok = 1
      }
      emit_seg()
    }
  '
}

wrapper_value_options() {
  case "$1" in
    sudo) printf '%s' ' -u -g -C -h -p -U -r -t -D -R -T ' ;;
    env) printf '%s' ' -u -C -P -S ' ;;
    nice) printf '%s' ' -n ' ;;
    timeout) printf '%s' ' -s -k --signal --kill-after ' ;;
    xargs) printf '%s' ' -I -n -P -L -s -E -d -a -J -R -S ' ;;
  esac
}

parse_segment() {
  local IFS="$CRAFT_SEP" t w values
  local -a toks words
  read -r -a toks <<< "$1"
  CMD=""
  ARGS=()
  OUTS=()
  VIA_XARGS=0
  words=()
  for t in ${toks[@]+"${toks[@]}"}; do
    case "$t" in
      '>'*) OUTS+=("${t#>}") ;;
      '<'*|'&'*) ;;
      *) words+=("$t") ;;
    esac
  done

  local i=0 n=${#words[@]}
  while [ "$i" -lt "$n" ]; do
    w=${words[$i]}
    if [[ "$w" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i + 1)); continue; fi
    case "$w" in
      '{'|'!'|then|do|else|elif|if|while|until|time|nohup|builtin|exec)
        i=$((i + 1)) ;;
      command)
        case "${words[$((i + 1))]:-}" in -v|-V) return 0 ;; esac
        i=$((i + 1))
        [ "${words[$i]:-}" = "-p" ] && i=$((i + 1)) ;;
      sudo|env|nice|timeout|xargs)
        [ "$w" = xargs ] && VIA_XARGS=1
        values=$(wrapper_value_options "$w")
        i=$((i + 1))
        while [ "$i" -lt "$n" ] && [[ "${words[$i]}" == -* ]]; do
          case "$values" in *" ${words[$i]} "*) i=$((i + 2)) ;; *) i=$((i + 1)) ;; esac
        done
        [ "$w" = timeout ] && i=$((i + 1)) ;;
      *) break ;;
    esac
  done

  [ "$i" -lt "$n" ] || return 0
  CMD=${words[$i]##*/}
  for ((i = i + 1; i < n; i++)); do ARGS+=("${words[$i]}"); done
}

drop_args() {
  local count="$1" i
  local -a kept=()
  for ((i = count; i < ${#ARGS[@]}; i++)); do kept+=("${ARGS[$i]}"); done
  ARGS=(${kept[@]+"${kept[@]}"})
}

manifest_kind() {
  case "$1" in
    package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lock|bun.lockb|Cargo.lock|go.sum|poetry.lock|uv.lock|pdm.lock|Pipfile.lock|pubspec.lock|Podfile.lock|Gemfile.lock|composer.lock|gradle.lockfile|Package.resolved)
      printf 'lock' ;;
    package.json|pyproject.toml|Pipfile|Cargo.toml|go.mod|pubspec.yaml|Podfile|Gemfile|composer.json)
      printf 'cli' ;;
    build.gradle|build.gradle.kts|settings.gradle|settings.gradle.kts|libs.versions.toml|pom.xml|Package.swift|requirements*.txt)
      printf 'manual' ;;
  esac
}

js_manager() {
  local dir="$1"
  if [ -e "$dir/bun.lock" ] || [ -e "$dir/bun.lockb" ]; then printf 'bun'
  elif [ -e "$dir/pnpm-lock.yaml" ]; then printf 'pnpm'
  elif [ -e "$dir/yarn.lock" ]; then printf 'yarn'
  elif [ -e "$dir/package-lock.json" ]; then printf 'npm'
  else printf 'bun'
  fi
}

python_manager() {
  local dir="$1"
  if [ -e "$dir/poetry.lock" ]; then printf 'poetry'
  elif [ -e "$dir/pdm.lock" ]; then printf 'pdm'
  elif [ -e "$dir/Pipfile" ]; then printf 'pipenv'
  else printf 'uv'
  fi
}

add_remove_hint() {
  case "$1" in
    npm) printf 'npm install <pkg>   /   npm uninstall <pkg>' ;;
    pipenv) printf 'pipenv install <pkg>   /   pipenv uninstall <pkg>' ;;
    *) printf '%s add <pkg>   /   %s remove <pkg>' "$1" "$1" ;;
  esac
}

manifest_hint() {
  local base="$1" dir="$2"
  case "$base" in
    package.json) printf 'Run:  %s' "$(add_remove_hint "$(js_manager "$dir")")" ;;
    package-lock.json|npm-shrinkwrap.json) printf 'Run:  %s' "$(add_remove_hint npm)" ;;
    yarn.lock) printf 'Run:  %s' "$(add_remove_hint yarn)" ;;
    pnpm-lock.yaml) printf 'Run:  %s' "$(add_remove_hint pnpm)" ;;
    bun.lock|bun.lockb) printf 'Run:  %s' "$(add_remove_hint bun)" ;;
    pyproject.toml) printf 'Run:  %s' "$(add_remove_hint "$(python_manager "$dir")")" ;;
    poetry.lock) printf 'Run:  %s' "$(add_remove_hint poetry)" ;;
    pdm.lock) printf 'Run:  %s' "$(add_remove_hint pdm)" ;;
    uv.lock) printf 'Run:  %s' "$(add_remove_hint uv)" ;;
    Pipfile|Pipfile.lock) printf 'Run:  %s' "$(add_remove_hint pipenv)" ;;
    Cargo.toml|Cargo.lock) printf 'Run:  cargo add <crate>   /   cargo remove <crate>' ;;
    go.mod|go.sum) printf 'Run:  go get <module>   /   go mod edit   /   go mod tidy' ;;
    pubspec.yaml|pubspec.lock) printf 'Run:  flutter pub add <pkg>   (or dart pub add; no pin, let it resolve the current version)' ;;
    Podfile|Podfile.lock) printf 'Edit the Podfile deliberately, then run:  pod install   /   pod update' ;;
    Gemfile|Gemfile.lock) printf 'Run:  bundle add <gem>   /   bundle remove <gem>' ;;
    composer.json|composer.lock) printf 'Run:  composer require <pkg>   /   composer remove <pkg>' ;;
    Package.resolved) printf 'Run:  swift package resolve   /   swift package update' ;;
    gradle.lockfile) printf 'Run:  ./gradlew dependencies --write-locks' ;;
    *) printf 'Run the ecosystem tool and let it write the file.' ;;
  esac
}

is_write_tool() { [ "$(jq -r '.tool_input | has("content")' <<< "$1")" = true ]; }

old_fragment() {
  if is_write_tool "$1"; then
    [ -f "$2" ] && cat "$2"
    return 0
  fi
  jq -r '.tool_input | if has("edits") then [.edits[].old_string] | join("\n") else (.old_string // "") end' <<< "$1"
}

new_fragment() {
  jq -r '.tool_input | .content // (if has("edits") then [.edits[].new_string] | join("\n") else (.new_string // "") end)' <<< "$1"
}

edited_file_text() {
  jq -r --rawfile file "$2" '
    def apply($e):
      if ($e.old_string // "") == "" then .
      elif ($e.replace_all // false) then split($e.old_string) | join($e.new_string)
      else split($e.old_string) as $parts
        | if ($parts | length) < 2 then . else $parts[0] + $e.new_string + ($parts[1:] | join($e.old_string)) end
      end;
    .tool_input as $t
    | if $t.content != null then $t.content
      elif $t.edits != null then reduce $t.edits[] as $e ($file; apply($e))
      else $file | apply($t)
      end' <<< "$1"
}

trimmed_lines() { printf '%s\n' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$'; }

added_lines() { grep -Fxv -f <(trimmed_lines "$1") <(trimmed_lines "$2"); }
