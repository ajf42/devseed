#!/usr/bin/env bash
#
# stop-gate.sh -- Stop. Runs the full gate before the turn is allowed to end,
# and blocks the end on failure, handing the agent the gate's own stderr.
#
# THIS IS THE LOAD-BEARING HOOK. It is the mechanical form of "do not consider a
# task complete until every step is done". Everything else in this directory
# reports; this one refuses.
#
# It answers with {"decision":"block","reason":...} rather than exit 2, because
# JSON is only honoured on exit 0 and the reason field is what puts the specific
# failure in front of the agent. Exit 2 would block too, but with stderr framed
# as a hook error rather than as work remaining.
#
# LOOP GUARD: today's hooks API has no stop_hook_active flag, so nothing outside
# this script stops it re-blocking a failure the agent cannot fix -- a wedged
# session with no exit. After MAX_BLOCKS consecutive blocks it stops blocking
# and escalates to the human instead. That is a degradation, so it is made as
# loud as the block was. See ADR-0008.
HOOK_NAME="Stop/gate"
MAX_BLOCKS=3
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! have_jq; then
  { hook_jq_advice
    printf '\nThe Stop gate cannot report a failure reason without it, and a gate\n'
    printf 'that cannot report is a gate that does not run. Blocking on exit 2.\n'
  } >&2
  exit 2
fi

ROOT="$(hook_root)"
GATE="$(hook_gate)"
STATE="$(hook_state_dir)"
SLUG="$(hook_session_slug)"
COUNT_F="$STATE/stop-blocks-$SLUG"
RESULT_F="$STATE/last-gate-$SLUG"

block() {
  jq -n --arg r "$1" '{decision:"block",reason:$r}'
  exit 0
}

if [ ! -f "$GATE" ]; then
  printf 'fail: gate missing at %s\n' "$GATE" >"$RESULT_F" 2>/dev/null
  block "The gate is missing at $GATE, so nothing verified this turn.

A check that cannot run is a failed check (DESIGN.md §5). Restore
plugins/governed-dev/gates/gate.sh rather than treating this as done."
fi

ERR="$(CLAUDE_PROJECT_DIR="$ROOT" bash "$GATE" 2>&1 >/dev/null)"
RC=$?

if [ "$RC" = 0 ]; then
  printf 'pass\n' >"$RESULT_F" 2>/dev/null
  rm -f "$COUNT_F" 2>/dev/null
  exit 0
fi

printf 'fail (exit %s)\n' "$RC" >"$RESULT_F" 2>/dev/null

N=0
[ -f "$COUNT_F" ] && N="$(cat "$COUNT_F" 2>/dev/null)"
case "$N" in ''|*[!0-9]*) N=0 ;; esac
N=$((N + 1))
printf '%s' "$N" >"$COUNT_F" 2>/dev/null

if [ "$N" -gt "$MAX_BLOCKS" ]; then
  rm -f "$COUNT_F" 2>/dev/null
  { printf 'STOP GATE: releasing after %s consecutive blocked attempts.\n\n' "$MAX_BLOCKS"
    printf 'The gate still fails:\n\n%s\n\n' "$ERR"
    printf 'This turn is NOT done. The hook stopped blocking because a gate that\n'
    printf 'cannot be satisfied wedges the session with no way out, not because\n'
    printf 'the work passed. Someone has to look at this -- the failure above has\n'
    printf 'survived %s attempts to fix it and is likely not the agent'"'"'s to fix.\n' "$MAX_BLOCKS"
  } >&2
  jq -n --arg m "Stop gate released after $MAX_BLOCKS blocked attempts; the gate still fails and the work is unfinished. See the hook output above." \
    '{systemMessage:$m}'
  exit 0
fi

block "The gate failed, so this turn is not done. Attempt $N of $MAX_BLOCKS.

$ERR

Fix the failure above and finish the task. Do not report completion, and do not
work around the gate: it is the definition of done (DESIGN.md §5), and its
messages name the file and the action to take.

If the failure is one you genuinely cannot fix -- a missing toolchain, a
requirement the spec never settled -- say so plainly and stop. After
$MAX_BLOCKS attempts this hook stops blocking and escalates to the human, and a
turn that ends that way ends unfinished."
