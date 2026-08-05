#!/usr/bin/env bash
# Check 4 -- code changed => working memory changed. Sourced by gate.sh.
CHECK="4/7 working memory"
require_git

_ch="$(changed_files)"

if printf '%s\n' "$_ch" | grep -q '^src/'; then
  printf '%s\n' "$_ch" | grep -qx 'CLAUDE.md' || die \
"Files under src/ changed but CLAUDE.md did not. Update the 'Current state' section of CLAUDE.md to describe what now exists, then re-run the gate. A code change with stale working memory is not done -- the next session reads CLAUDE.md as authoritative for what is there."
fi

unset _ch
