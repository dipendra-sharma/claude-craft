#!/bin/bash

craft_rules_off() { [ "${CLAUDE_CRAFT_RULES:-on}" = "off" ]; }

require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  printf 'craft-proof: jq is not installed, so the proof hooks are not running. Install it: brew install jq\n' >&2
  exit 1
}
