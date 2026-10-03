#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
is_git || exit 0

[ "$(cat "$OUTCOME" 2>/dev/null)" = proven ] || exit 0
archive_task
take_baseline
exit 0
