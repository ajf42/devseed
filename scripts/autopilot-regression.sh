#!/usr/bin/env bash
#
# autopilot-regression.sh -- asserts autopilot's ROUTING, against a scratch
# project and a fake worker.
#
# What is being tested is the router, not the worker. Every case fixes what the
# repository looks like after the worker runs and asserts which way autopilot
# went: continue, or stop and surface. That is the whole feature -- a driver
# that routed the wrong way would hand the human either a decision queue full
# of noise or, far worse, a digest line for work that never agreed with the
# spec, which is the hand-carried-summary failure with a machine doing the
# carrying.
#
# THE WORKER IS FAKE, THE GATE IS REAL. `claude` is not installed on the
# machine devseed is developed on, and a suite that cannot run asserts nothing
# (T-030). So the worker is a stub whose behaviour each case pins, while the
# gate autopilot consults is the real plugins/governed-dev/gates/gate.sh run
# against the scratch project. The router's input is therefore genuine.
#
# devseed's own dev tooling. Not shipped in the plugin.
#
# Usage: bash scripts/autopilot-regression.sh   (exit 0 = all assertions passed)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AP="$HERE/scripts/autopilot.sh"
GATE="$HERE/plugins/governed-dev/gates/gate.sh"
WORK="${TMPDIR:-/tmp}/devseed-autopilot-regression.$$"
PROJ="$WORK/proj"
FAKE="$WORK/fake-claude.sh"
MODE_F="$WORK/mode"
FSTATE="$WORK/fake-state"
PASS=0; FAIL=0

trap 'rm -rf "$WORK"' EXIT

ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }

# Ids assembled at runtime so this file does not flag ITSELF: drift check 3
# resolves every SG-NNNN and ADR-NNNN it finds in a tracked file, and a
# deliberately dangling id in a fixture is indistinguishable from a real
# orphan. Same dodge gate-regression.sh and check-06-spec-gaps.sh use.
_SG="SG-00"; _SG="${_SG}99"

# ---------------------------------------------------------------------------
# The fake worker. Reads its mode from a file outside the project, does to the
# repository exactly what that mode says, and answers in the JSON shape
# `claude -p --output-format json` produces.
# ---------------------------------------------------------------------------
write_fake() {
  mkdir -p "$FSTATE"
  cat > "$FAKE" <<'FAKE'
#!/usr/bin/env bash
# Fake `claude`, for autopilot-regression.sh. Not a simulation of Claude Code:
# a fixture that puts the repository into a known state and reports in the
# right JSON shape.
set -uo pipefail
PROMPT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -p) PROMPT="${2:-}"; shift 2 ;;
    *)  shift ;;
  esac
done

T="$(printf '%s' "$PROMPT" | grep -oE 'T-[0-9]+' | head -1)"
MODE="$(cat "$FAKE_MODE_FILE" 2>/dev/null)"
ATT_F="$FAKE_STATE/attempts-$T"
N=0; [ -f "$ATT_F" ] && N="$(cat "$ATT_F")"
N=$((N + 1)); printf '%s' "$N" > "$ATT_F"

RESULT="Ran $T. Gate passed, committed."
COST="0.1200"
JSON_OK=1

commit_with_trailer() {   # subject
  git add -A >/dev/null 2>&1
  git commit -q -m "$1" -m "Task-Id: $T
Agent-Type: main" >/dev/null 2>&1
}

# Move the task off `todo` the way /task does: in-progress, hash next commit.
mark_in_progress() {
  awk -v want="$T" '
    /^## T-[0-9]+/ { have = ($2 == want) }
    have && /^- \*\*Status:\*\* *todo/ { print "- **Status:** in-progress"; next }
    { print }
  ' TASKS.md > TASKS.md.new && mv TASKS.md.new TASKS.md
}

case "$MODE" in
  agree)
    printf 'work for %s\n' "$T" > "notes/$T.md"
    mark_in_progress
    commit_with_trailer "notes: record $T's output"
    ;;
  sg)
    printf 'work for %s\n' "$T" > "notes/$T.md"
    mark_in_progress
    printf '\n### %s — the fixture gap\n\n- **Status:** Open\n\n**Assumed:** the fixture assumed something the spec never said.\n' \
      "$FAKE_SG_ID" >> DECISIONS.md
    commit_with_trailer "notes: record $T's output"
    RESULT="Ran $T. Recorded a spec gap."
    ;;
  amend)
    printf 'work for %s\n' "$T" > "notes/$T.md"
    mark_in_progress
    commit_with_trailer "notes: record $T's output"
    RESULT="Ran $T. This needs an amendment to DESIGN.md; propose running /amend."
    ;;
  question)
    printf 'work for %s\n' "$T" > "notes/$T.md"
    mark_in_progress
    commit_with_trailer "notes: record $T's output"
    RESULT="Ran $T, but which of the two shapes did you want?"
    ;;
  gatefail)
    # A done task citing a hash that resolves to nothing: check 5's own case,
    # so the gate says exit 2 for a real and recognisable reason.
    printf '\n## T-900 — fabricated\n\n- **Status:** done\n- **Commit:** `deadbee`\n' >> TASKS.md
    mark_in_progress
    commit_with_trailer "notes: record $T's output"
    ;;
  gatefail-then-ok)
    if [ "$N" = 1 ]; then
      printf '\n## T-900 — fabricated\n\n- **Status:** done\n- **Commit:** `deadbee`\n' >> TASKS.md
      mark_in_progress
      commit_with_trailer "notes: record $T's output"
    else
      awk '/^## T-900/ { skip = 1 } /^## T-[0-9]+/ && !/^## T-900/ { skip = 0 } !skip { print }' \
        TASKS.md > TASKS.md.new && mv TASKS.md.new TASKS.md
      commit_with_trailer "tasks: drop the fabricated entry"
      RESULT="Ran $T. Fixed the gate's finding and committed."
    fi
    ;;
  nocommit)
    # Reports success, changes nothing. The exact shape of the failure
    # autopilot exists to catch: a clean account of work the repository has
    # no record of.
    RESULT="Ran $T. All done, everything committed."
    ;;
  malformed)
    JSON_OK=0
    ;;
  expensive)
    printf 'work for %s\n' "$T" > "notes/$T.md"
    mark_in_progress
    commit_with_trailer "notes: record $T's output"
    COST="9.9900"
    ;;
  crash)
    printf 'the worker fell over\n' >&2
    exit 3
    ;;
esac

if [ "$JSON_OK" = 0 ]; then
  printf 'Execution error: something went wrong before any JSON was produced.\n'
  exit 0
fi

jq -n --arg r "$RESULT" --arg s "sess-${T}-${N}" --argjson c "$COST" \
  '{type:"result",subtype:"success",is_error:false,result:$r,session_id:$s,total_cost_usd:$c,num_turns:7}'
FAKE
  chmod +x "$FAKE" 2>/dev/null
}

# ---------------------------------------------------------------------------
# The scratch project. Honest enough that the REAL gate passes on it: four
# ledger documents, a structure block that matches the tree, three todo tasks.
#
# reports/ is committed with a README rather than left to be created, because a
# structure block naming a directory that does not exist is itself drift -- the
# same requirement autopilot imposes on any repository that runs it.
# ---------------------------------------------------------------------------
scaffold() {
  # The strike counters go too. They are deliberately durable across
  # invocations -- that is the point of a circuit breaker -- so a case that did
  # not clear them would inherit the previous case's strikes and pass or fail
  # for a reason that has nothing to do with what it tests.
  rm -rf "$PROJ" "$FSTATE" "$WORK/state"; mkdir -p "$PROJ/notes" "$PROJ/reports" "$FSTATE"
  cd "$PROJ" || exit 2
  git init -q .
  git symbolic-ref HEAD refs/heads/main
  git config user.email autopilot@local
  git config user.name autopilot-regression

  cat > DESIGN.md <<'MD'
# DESIGN.md — probe

## 1. What this is
A scratch project.

## 5. Build rules
Exit 0 is pass, exit 2 is fail. A check that cannot run is a failed check.

## 6. Amendment procedure
Placeholder.
MD

  cat > CLAUDE.md <<'MD'
# CLAUDE.md — probe

## Current state
A scratch project driven by autopilot.

## File structure as it stands

```
DESIGN.md                          spec
CLAUDE.md                          this file
DECISIONS.md                       decisions and spec gaps
TASKS.md                           backlog
notes/                             where the worker writes
reports/                           autopilot run reports
  README.md                        what lands here
```
MD

  printf '# DECISIONS.md\n\n## Spec gaps observed\n\n### SG-0001 — a gap\nBody.\n' > DECISIONS.md
  printf '# reports\n\nAutopilot run reports.\n' > reports/README.md
  printf 'placeholder\n' > notes/.keep

  {
    printf '# TASKS.md\n'
    for n in 001 002 003; do
      printf '\n## T-%s — task %s\n\n- **Description:** a task.\n- **Status:** todo\n- **Commit:** —\n' "$n" "$n"
    done
  } > TASKS.md

  git add -A >/dev/null 2>&1
  git commit -qm init >/dev/null 2>&1
  git checkout -q -b work
}

# mode <name> -- what the fake worker does on its next invocation
mode() { printf '%s' "$1" > "$MODE_F"; }

# run_ap <expected-exit> <description> [args...]
# Leaves the run's stdout+stderr in $OUT and the report body in $REPORT_BODY.
run_ap() {
  local want="$1" desc="$2"; shift 2
  local got
  OUT="$( cd "$PROJ" && \
    AUTOPILOT_CLAUDE_BIN="$FAKE" \
    AUTOPILOT_GATE="$GATE" \
    AUTOPILOT_TASK_SKILL="/task" \
    AUTOPILOT_STATE_DIR="$WORK/state" \
    FAKE_MODE_FILE="$MODE_F" \
    FAKE_STATE="$FSTATE" \
    FAKE_SG_ID="$_SG" \
    bash "$AP" "$@" 2>&1 )"
  got=$?
  if [ "$got" = "$want" ]; then ok "$desc (exit $got)"; else bad "$desc -- wanted exit $want, got $got"; fi
  [ "$got" != 1 ] || bad "$desc RETURNED 1 -- exit 1 does not block and must never be returned"

  REPORT_BODY=""
  local rp
  rp="$(ls -1 "$PROJ"/reports/autopilot-*.md 2>/dev/null | tail -1)"
  [ -n "$rp" ] && REPORT_BODY="$(cat "$rp")"
}

# says <needle> <description>   -- assert on the run's own output
says() {
  case "$OUT" in
    *"$1"*) ok "$2" ;;
    *)      bad "$2 -- output does not contain '$1'"; printf '%s\n' "$OUT" | sed 's/^/        /' ;;
  esac
}

# reports <needle> <description>  /  reports_not <needle> <description>
reports() {
  case "$REPORT_BODY" in
    *"$1"*) ok "$2" ;;
    *)      bad "$2 -- report does not contain '$1'"; printf '%s\n' "$REPORT_BODY" | sed 's/^/        /' ;;
  esac
}
reports_not() {
  case "$REPORT_BODY" in
    *"$1"*) bad "$2 -- report contains '$1' and should not" ;;
    *)      ok "$2" ;;
  esac
}

echo "autopilot regression: $AP"
[ -f "$AP" ] || { printf '  FAIL  no autopilot.sh at %s\n' "$AP"; exit 2; }
write_fake
command -v jq >/dev/null 2>&1 || { printf '  FAIL  jq is required by the fake worker and by autopilot.\n'; exit 2; }


# --- The two rules that are properties of the FILE, not of a run -------------
# Both are boundaries stated in the header, and both are the kind that decay
# silently: an edit adding a push or a permission flag would look like a
# convenience and nothing else would notice.
echo
echo "boundaries -- asserted against the script itself:"
# Comment lines are stripped first: the header says the rule in prose ("there
# is no `git push` in this file"), and an assertion that cannot tell the rule
# from a violation of it would fail on the sentence stating the rule.
if grep -vE '^[[:space:]]*#' "$AP" | grep -qE 'git[[:space:]]+push'; then
  bad "autopilot.sh contains a 'git push' -- it must never push"
else
  ok "autopilot.sh contains no 'git push' outside its comments"
fi
if grep -qE '^[^#]*(--dangerously-skip-permissions|--permission-mode|--allowedTools)' "$AP" \
   && ! grep -qE 'assert_no_widening' "$AP"; then
  bad "autopilot.sh passes a permission-widening flag to the worker"
else
  ok "autopilot.sh widens no permission allowlist (and asserts so at runtime)"
fi


# --- Preflight refusals ------------------------------------------------------
# A refusal writes no report: the loop never started, and writing into a tree
# autopilot has just refused to touch is the failure it refused for.
echo
echo "preflight -- refuses to start:"

scaffold
printf 'uncommitted\n' > "$PROJ/notes/dirty.md"
mode agree
run_ap 2 "dirty tree refuses to start"
says "working tree is not clean" "dirty tree -- names the reason"
if ls "$PROJ"/reports/autopilot-*.md >/dev/null 2>&1; then
  bad "dirty tree -- a report was written despite the refusal"
else
  ok "dirty tree -- no report written (the loop never started)"
fi

scaffold
git -C "$PROJ" checkout -q main
mode agree
run_ap 2 "default branch refuses to start"
says "the default branch" "main -- names the reason"
says "--create-branch" "main -- offers the remedy rather than taking it"
if [ "$(git -C "$PROJ" rev-parse --abbrev-ref HEAD)" = main ]; then
  ok "main -- HEAD was not moved by the refusal"
else
  bad "main -- the refusal moved HEAD anyway"
fi

scaffold
git -C "$PROJ" checkout -q main
mode agree
run_ap 0 "--create-branch on main creates autopilot/DATE and proceeds" --create-branch --max-tasks 1
case "$(git -C "$PROJ" rev-parse --abbrev-ref HEAD)" in
  autopilot/*) ok "--create-branch -- HEAD is on autopilot/$(date +%Y-%m-%d)" ;;
  *)           bad "--create-branch -- HEAD is $(git -C "$PROJ" rev-parse --abbrev-ref HEAD)" ;;
esac

scaffold
printf '\n## T-004 — broken\n\n- **Status:** done\n- **Commit:** `deadbee`\n' >> "$PROJ/TASKS.md"
( cd "$PROJ" && git add -A >/dev/null 2>&1 && git commit -qm "break the gate" >/dev/null 2>&1 )
mode agree
run_ap 2 "a failing gate refuses to start"
says "does not pass on the current tree" "failing gate -- names the reason"


# --- (a) AGREEMENT continues -------------------------------------------------
echo
echo "route (a) -- agreement continues:"
scaffold
mode agree
run_ap 0 "three agreeing tasks run to the run cap"
reports "COMPLETED WITHOUT YOU" "agreement -- the digest section exists"
reports "T-001" "agreement -- T-001 is in the digest"
reports "T-003" "agreement -- T-003 is in the digest"
reports_not "DECISIONS NEEDED" "agreement -- no decisions section when nothing disagreed"
says "no decisions needed" "agreement -- says so on stdout"

# The tree autopilot leaves behind must still pass the gate. It committed a
# report into a directory the structure block has to name -- a driver that
# left the repository failing its own gate would have broken the thing it
# routes on.
if ( cd "$PROJ" && CLAUDE_PROJECT_DIR="$PROJ" bash "$GATE" >/dev/null 2>&1 ); then
  ok "agreement -- the gate still passes on the tree autopilot left"
else
  bad "agreement -- autopilot left the gate failing"
fi

# One line per agreed task and no transcript: the digest is skimmable
# awareness, not a decision queue and not a log.
DIGEST_LINES="$(printf '%s\n' "$REPORT_BODY" | grep -c '^| T-00')"
if [ "$DIGEST_LINES" -ge 3 ]; then
  ok "agreement -- one digest/ledger line per task ($DIGEST_LINES rows)"
else
  bad "agreement -- expected at least 3 task rows, found $DIGEST_LINES"
fi


# --- Run cap -----------------------------------------------------------------
echo
echo "run cap -- autonomy is bounded:"
scaffold
mode agree
run_ap 0 "--max-tasks 1 stops after one task" --max-tasks 1
reports "run cap reached" "run cap -- the stop reason is the cap"
reports "T-001" "run cap -- the one completed task is in the digest"
reports_not "T-002" "run cap -- the second task was not started"
if [ "$(git -C "$PROJ" log --oneline main..HEAD | wc -l | tr -d ' ')" -le 2 ]; then
  ok "run cap -- at most two commits (the task's, and the report's)"
else
  bad "run cap -- more commits than the cap allows"
fi


# --- (b) DISAGREEMENT, spec kind ---------------------------------------------
echo
echo "route (b) -- spec disagreement stops the loop:"
scaffold
mode sg
run_ap 2 "a new SG entry stops the loop"
reports "DECISIONS NEEDED" "new SG -- the decisions section exists"
reports "$_SG" "new SG -- the entry's id is in the report"
reports "spec gap" "new SG -- classified as a spec gap"
reports "Options" "new SG -- the options are offered"
reports_not "T-002" "new SG -- the next task was not started"

scaffold
mode amend
run_ap 2 "an /amend-shaped proposal stops the loop"
reports "amendment" "amend -- classified as an amendment"
reports "human decides" "amend -- names §6's allocation"

scaffold
mode question
run_ap 2 "a question for the human stops the loop"
reports "question" "question -- classified as a question"
reports "which of the two shapes" "question -- quotes the worker's own line"


# --- (c) DISAGREEMENT, gate failure: one retry, then stop --------------------
echo
echo "route (c) -- gate failure retries once, then stops:"
scaffold
mode gatefail
run_ap 2 "gate exit 2 twice stops the loop"
says "Retrying once with the gate's findings appended" "gate failure -- retried exactly once"
if [ "$(cat "$FSTATE/attempts-T-001" 2>/dev/null)" = 2 ]; then
  ok "gate failure -- the worker was invoked twice, not more"
else
  bad "gate failure -- worker invoked $(cat "$FSTATE/attempts-T-001" 2>/dev/null) time(s), wanted 2"
fi
reports "gate failure" "gate failure -- classified as a gate failure"
reports "Strike 2 of 3" "gate failure -- both failures counted as strikes"
reports "deadbee" "gate failure -- the gate's own finding is quoted"

# Strikes persist across invocations, so a task cannot burn attempts forever by
# being re-run: the counter outlives the run, exactly as the Stop hook's block
# counter outlives a turn.
if [ "$(cat "$WORK/state/autopilot-strikes-T-001" 2>/dev/null)" = 2 ]; then
  ok "strikes -- the counter survived the run that earned it"
else
  bad "strikes -- counter is '$(cat "$WORK/state/autopilot-strikes-T-001" 2>/dev/null)', wanted 2"
fi

scaffold
mode gatefail-then-ok
run_ap 0 "a retry that fixes the finding continues as agreement" --max-tasks 1
if [ "$(cat "$FSTATE/attempts-T-001" 2>/dev/null)" = 2 ]; then
  ok "retry-then-pass -- two attempts, the second clean"
else
  bad "retry-then-pass -- worker invoked $(cat "$FSTATE/attempts-T-001" 2>/dev/null) time(s), wanted 2"
fi
reports "COMPLETED WITHOUT YOU" "retry-then-pass -- lands in the digest"
reports_not "DECISIONS NEEDED" "retry-then-pass -- needs no decision"

# At the ceiling the task is refused BEFORE the worker is called -- a fourth
# attempt at a failure that has survived three is spending money to reproduce a
# known result.
scaffold
mkdir -p "$WORK/state"; printf '3' > "$WORK/state/autopilot-strikes-T-001"
mode agree
run_ap 2 "a task at the strike ceiling is refused before the worker runs"
reports "used all 3 strikes" "strikes -- the circuit breaker opened"
if [ -f "$FSTATE/attempts-T-001" ]; then
  bad "strikes -- the worker was invoked despite the open circuit breaker"
else
  ok "strikes -- the worker was never invoked"
fi


# --- (d) fail closed ---------------------------------------------------------
echo
echo "route (d) -- anything unreadable stops the loop:"
scaffold
mode nocommit
run_ap 2 "a clean report with no commit is not agreement"
reports "unrouted" "no commit -- classified as unrouted"
reports "the repository is what autopilot routes on" "no commit -- names why the worker's account is not enough"

scaffold
mode malformed
run_ap 2 "output that is not JSON stops the loop"
reports "unreadable" "malformed -- classified as unreadable"

scaffold
mode crash
run_ap 2 "a nonzero worker exit stops the loop"
reports "worker/failed" "crash -- classified as a worker failure"

scaffold
mode expensive
run_ap 2 "the per-task cost ceiling stops the loop" --cost-ceiling 1.00
reports "budget" "cost ceiling -- classified as a budget stop"
reports "9.99" "cost ceiling -- the actual cost is shown"


# --- --dry-run ---------------------------------------------------------------
echo
echo "--dry-run -- preflight only:"
scaffold
mode agree
run_ap 0 "--dry-run passes preflight and stops" --dry-run
says "stopping before the first worker" "--dry-run -- says it stopped early"
if ls "$PROJ"/reports/autopilot-*.md >/dev/null 2>&1; then
  bad "--dry-run wrote a report"
else
  ok "--dry-run wrote no report"
fi
if [ "$(git -C "$PROJ" rev-parse HEAD)" = "$(git -C "$PROJ" rev-parse main)" ]; then
  ok "--dry-run made no commit"
else
  bad "--dry-run committed something"
fi

cd "$HERE" || exit 2
echo
echo "summary: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ] || exit 2
exit 0
