#!/usr/bin/env bash
#
# activity.sh -- SessionEnd and SubagentStop. Appends one line to
# .claude/activity.jsonl: what ran, what it touched, and whether the gate passed.
#
# ADR-0003 committed that file to git so the audit trail survives a clone and is
# visible in review. It has been empty since it was created, because nothing
# wrote to it until these hooks existed.
#
# Async and non-blocking by design, and doubly so at SessionEnd, which shares a
# 1.5s budget across every hook on the event. It never blocks and never fails
# the event: a missing audit line is a lesser harm than a session that cannot
# close. Every write is best-effort and every exit is 0.
HOOK_NAME="activity"
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

have_jq || {
  hook_note "jq missing; no activity record written. Run the Setup preflight for the fix."
  exit 0
}

ROOT="$(hook_root)"
[ -d "$ROOT/.claude" ] || exit 0
LOG="$ROOT/.claude/activity.jsonl"

STATE="$(hook_state_dir)"
SLUG="$(hook_session_slug)"

EVENT="$(hook_field '.hook_event_name')"
SESSION="$(hook_field '.session_id')"
AGENT="$(hook_field '.agent_type')"
REASON="$(hook_field '.exit_reason')"

GATE_RESULT="not run"
[ -f "$STATE/last-gate-$SLUG" ] && GATE_RESULT="$(cat "$STATE/last-gate-$SLUG" 2>/dev/null)"

COMMITS=""
if [ -f "$STATE/head-$SLUG" ]; then
  COMMITS="$(git -C "$ROOT" log --format='%h %s' \
    "$(cat "$STATE/head-$SLUG" 2>/dev/null)..HEAD" 2>/dev/null)"
fi

# jq -R -s -c 'split("\n")|map(select(length>0))' turns a newline-separated list
# into a JSON array with correct escaping. Building these arrays by hand is how
# one filename containing a quote produces a corrupt append-only log.
_arr() { printf '%s' "$1" | jq -R -s -c 'split("\n")|map(select(length>0))'; }

jq -n -c \
  --arg ts    "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)" \
  --arg ev    "${EVENT:-unknown}" \
  --arg sid   "${SESSION:-unknown}" \
  --arg agent "${AGENT:-main}" \
  --arg gate  "${GATE_RESULT:-not run}" \
  --arg why   "${REASON:-}" \
  --argjson files   "$(_arr "$(hook_changed_files)")" \
  --argjson commits "$(_arr "$COMMITS")" \
  '{timestamp:$ts,event:$ev,session_id:$sid,agent_type:$agent,
    files_touched:$files,gate_result:$gate,commits:$commits}
   + (if $why == "" then {} else {exit_reason:$why} end)' \
  >>"$LOG" 2>/dev/null

# Session-scoped scratch is only cleaned when the session itself ends. A
# SubagentStop shares the parent's session id, so clearing it there would erase
# the parent's start-HEAD and gate result mid-session.
if [ "$EVENT" = "SessionEnd" ]; then
  rm -f "$STATE/head-$SLUG" "$STATE/last-gate-$SLUG" "$STATE/stop-blocks-$SLUG" 2>/dev/null
fi

exit 0
