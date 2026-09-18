#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
cat >/dev/null

if craft_is_allowed slack; then
  craft_consume_allow slack
  exit 0
fi

printf 'Blocked: sending to Slack directly.\n\nUse slack_send_message_draft and let the user send it, so the message stays native with no "Sent using @Claude" footer.\nThe user explicitly told you to send it? Run  craft-allow slack  and retry. It allows one send.\n' >&2
exit 2
