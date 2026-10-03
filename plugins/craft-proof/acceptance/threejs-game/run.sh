#!/bin/bash
set -u

workspace=${1:?usage: run.sh <workspace with src/logic.js>}
logic="$workspace/src/logic.js"
if [ ! -f "$logic" ]; then
  printf 'tests 21\npass 0\nfail 21\n(no src/logic.js in %s)\n' "$workspace"
  exit 1
fi
LOGIC_PATH="$logic" /usr/local/bin/node --test --test-reporter=spec "$(dirname "$0")/logic.test.mjs" 2>&1
