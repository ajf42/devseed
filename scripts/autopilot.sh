#!/usr/bin/env bash
#
# autopilot.sh -- the driver loop above /task.
#
# WHAT THIS REPLACES. Between sessions the human is the transport layer,
# hand-carrying an account of work the repository already holds. Twice that
# account disagreed with the repository: a todo list carried forward stale, and
# a fix reported done that was not on main. Transport is the defect -- a
# summary is a claim about the repository made through a channel with no
# verification step in it (DESIGN.md §5, Known limits, the Layer 0 principle).
#
# Autopilot replaces transport with ROUTING. Work that AGREES with the spec
# proceeds without human attention; only DISAGREEMENTS surface. It routes on
# the gate's verdict, obtained by running the gate itself after the worker --
# never on the worker's account of its own correctness. That distinction is the
# whole feature: a driver that believed its worker would be transport again,
# with one more hop.
#
# THE GATE IS THE ROUTER. It is already the single definition of agreement
# (DESIGN.md §5). Autopilot adds no enforcement mechanism and relaxes none; it
# is a CONSUMER of the gate's verdict, not a second opinion on it. If autopilot
# and the gate ever disagree about a task's status, the gate is right and that
# is a bug here. See ADR-0030.
#
# WHAT IT NEVER DOES, mechanically as well as by intent:
#   - never edits DESIGN.md, never runs /amend, never resolves an SG entry.
#     §6's human-approval requirement is the load-bearing wall this is built
#     against, not an obstacle to it. Disagreement handling is proposal-only.
#   - never pushes, never merges. There is no `git push` in this file.
#   - never widens a permission allowlist to make automation smoother. The
#     worker runs with exactly the permissions the interactive /task flow
#     grants. If a permission prompt blocks headless execution, that is a
#     finding to report, not a setting to loosen. assert_no_widening() below
#     enforces this against future edits.
#   - never commits anything but its own run report, and only on a non-default
#     branch. /task remains the only thing that commits WORK (ADR-0030).
#
# BOUNDED BY DESIGN (a §5-style constraint of this script):
#   at most --max-tasks tasks per invocation (default 3); --max-turns and a
#   per-task cost ceiling on the worker; a per-task wall clock; three strikes
#   per task before it is refused outright. Autonomy that is not bounded is not
#   autonomy, it is an unattended process with a credit card.
#
# NEVER ON A DIRTY TREE. The citation is the TMPDIR incident (ADR-0028): an
# improvised probe ran in the repository root instead of a scratch directory
# and truncated three ledgers, 2,675 deletions, recovered only because someone
# noticed. Starting from a fully committed tree is what makes everything this
# script provokes attributable and revertible. Improvised state is forbidden.
#
# FAIL CLOSED. An autopilot that cannot read its worker's verdict does not
# guess. Malformed JSON, a nonzero exit, a timeout, a blown cost ceiling: stop
# the loop and report. Every ambiguity in the routing rules below resolves
# toward stopping, because a false stop costs a human one minute of reading and
# a false continue costs whatever the next three tasks build on top of it.
#
# EXIT CODES: 0 = ran to the run cap or the end of the queue with every task in
# agreement. 2 = anything else -- a preflight refusal, or a stop. NEVER 1, for
# the reason gate.sh gives: exit 1 does not block.
#
# Usage:  bash scripts/autopilot.sh [options] [T-NNN ...]
#         bash scripts/autopilot.sh --help
#
# devseed's own dev tooling, alongside the three regression suites. It does not
# ship in the plugin; the skill that wraps it does. See SG-0012.
#
# Deliberately not `set -e`: exit codes carry meaning here, and -e would
# surface a routing decision as exit 1, which blocks nothing.
set -uo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  printf 'AUTOPILOT REFUSED: this requires bash. Run it as: bash %s\n' "$0" >&2
  exit 2
fi

# --- config defaults --------------------------------------------------------
# Read here and overridable by flag, per T-041. Deliberately NOT a config file:
# a new file format nothing else in this repository reads would be invented
# structure, and the next reader would have to discover it. These are the
# config, and the flags are the override.
MAX_TASKS=3           # tasks per invocation. The run cap. Autonomy is bounded.
MAX_TURNS=40          # --max-turns handed to the worker
COST_CEILING=2.00     # USD per task; exceeded after the fact is a stop
TASK_TIMEOUT=1800     # seconds of wall clock per task attempt
MAX_STRIKES=3         # per task, across invocations. ADR-0008's pattern.

# --- test seams -------------------------------------------------------------
# Named here so they are findable, and so nothing else in this file reaches for
# an environment variable ad hoc. autopilot-regression.sh sets CLAUDE_BIN to a
# fake worker: there is no `claude` CLI on the machine devseed is developed on,
# and a suite that cannot run asserts nothing (T-030's lesson).
CLAUDE_BIN="${AUTOPILOT_CLAUDE_BIN:-claude}"

usage() {
  cat <<'USAGE'
autopilot.sh -- run /task headless over the todo queue, routing on the gate.

  bash scripts/autopilot.sh [options] [T-NNN ...]

Given task ids, it runs exactly those, in order. Given none, it takes the first
`todo` in TASKS.md, top to bottom, re-reading after each task.

Options:
  --max-tasks N       tasks per invocation (default 3)
  --max-turns N       --max-turns handed to the worker (default 40)
  --cost-ceiling USD  per-task ceiling; exceeding it stops the loop (default 2.00)
  --timeout SEC       wall clock per task attempt (default 1800)
  --create-branch     if on the default branch, create and switch to
                      autopilot/YYYY-MM-DD. Without this, being on the default
                      branch is a refusal -- switching branches under someone
                      unasked is the improvised state ADR-0028 is about.
  --dry-run           preflight and print the queue; run no worker, write no report
  --help              this

Stops write reports/autopilot-DATE.md and print its path. Preflight refusals do
not: the loop never started, and writing into a tree autopilot just refused to
touch is the failure it refused for.
USAGE
}

TASK_IDS=""
CREATE_BRANCH=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --max-tasks)      MAX_TASKS="${2:-}"; shift 2 ;;
    --max-turns)      MAX_TURNS="${2:-}"; shift 2 ;;
    --cost-ceiling)   COST_CEILING="${2:-}"; shift 2 ;;
    --timeout)        TASK_TIMEOUT="${2:-}"; shift 2 ;;
    --create-branch)  CREATE_BRANCH=1; shift ;;
    --dry-run)        DRY_RUN=1; shift ;;
    --help|-h)        usage; exit 0 ;;
    T-[0-9]*)         TASK_IDS="$TASK_IDS $1"; shift ;;
    *)                printf 'AUTOPILOT REFUSED: unknown argument "%s". See --help.\n' "$1" >&2; exit 2 ;;
  esac
done

case "$MAX_TASKS$MAX_TURNS$TASK_TIMEOUT" in
  ''|*[!0-9]*) printf 'AUTOPILOT REFUSED: --max-tasks, --max-turns and --timeout take integers.\n' >&2; exit 2 ;;
esac

say()    { printf 'autopilot: %s\n' "$1" >&2; }
refuse() { printf '\nAUTOPILOT REFUSED: %s\n' "$1" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Preflight. Every one of these is a refusal to start, not a warning. The loop
# either begins from a state it can reason about or it does not begin.
# ---------------------------------------------------------------------------

command -v git >/dev/null 2>&1 || refuse "git is not on PATH."
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$ROOT" ] || refuse "not inside a git repository."
cd "$ROOT" || refuse "cannot enter $ROOT."

command -v jq >/dev/null 2>&1 || refuse \
"jq is not installed, and the worker's verdict arrives as JSON.
Reading it with anything else is guessing, and this script does not guess.
  Windows   winget install --id jqlang.jq -e
  macOS     brew install jq
  Debian    sudo apt-get install jq"

GATE="${AUTOPILOT_GATE:-$ROOT/plugins/governed-dev/gates/gate.sh}"
[ -f "$GATE" ] || GATE="${CLAUDE_PLUGIN_ROOT:-}/gates/gate.sh"
[ -f "$GATE" ] || refuse \
"no gate at $GATE.
The gate is the router. Without it there is nothing to route on, and a driver
that proceeds anyway is transport with extra steps."

command -v "$CLAUDE_BIN" >/dev/null 2>&1 || refuse \
"no \`$CLAUDE_BIN\` on PATH, so there is no worker to drive.
Install the Claude Code CLI, or point AUTOPILOT_CLAUDE_BIN at it."

[ -f TASKS.md ] || refuse "no TASKS.md at $ROOT -- nothing to pick from."
[ -f DECISIONS.md ] || refuse "no DECISIONS.md at $ROOT -- spec-gap detection has nothing to read."

# 1. Clean tree. See the TMPDIR note in the header: this is the citation for
#    why improvised state is forbidden, and it is a refusal rather than a
#    warning because everything downstream -- the before/after diffs, the
#    hash attribution, the "what did the worker change" question the report
#    answers -- is defined against a committed baseline.
DIRTY="$(git status --porcelain 2>/dev/null)"
[ -z "$DIRTY" ] || refuse \
"the working tree is not clean:

$DIRTY

Commit or stash first. Autopilot measures what the worker changed by diffing
against the commit it started from; uncommitted work makes that measurement a
guess, and an improvised probe running against a live tree is the incident
ADR-0028 records (three ledgers truncated, 2,675 deletions)."

# 2. Not the default branch. The remedy is offered, not taken silently.
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

case "$BRANCH" in
  main|master)
    if [ "$CREATE_BRANCH" = 1 ]; then
      NEW_BRANCH="autopilot/$(date +%Y-%m-%d)"
      if git show-ref --verify --quiet "refs/heads/$NEW_BRANCH"; then
        git checkout -q "$NEW_BRANCH" || refuse "cannot switch to existing branch $NEW_BRANCH."
      else
        git checkout -q -b "$NEW_BRANCH" || refuse "cannot create branch $NEW_BRANCH."
      fi
      BRANCH="$NEW_BRANCH"
      say "created and switched to $BRANCH (--create-branch)."
    else
      refuse \
"on \`$BRANCH\`, the default branch. Autopilot does not work there.

Re-run with --create-branch to have it create and switch to
autopilot/$(date +%Y-%m-%d), or switch to a branch yourself. It is not done
automatically because moving someone's HEAD unasked is exactly the improvised
state that has already cost this repository once (ADR-0028)."
    fi
    ;;
esac

# 3. The gate passes NOW. Starting from red means every later verdict is
#    inherited rather than caused, and the first task would be blamed for it.
GATE_ERR="$(CLAUDE_PROJECT_DIR="$ROOT" bash "$GATE" 2>&1 >/dev/null)"
GATE_RC=$?
[ "$GATE_RC" = 0 ] || refuse \
"the gate does not pass on the current tree (exit $GATE_RC):

$GATE_ERR

Autopilot routes on the gate's verdict. Starting from a failing gate means
every task's verdict is inherited from a failure it did not cause."

# The strike counter shares the hook scratch directory, and the counter file
# has the same shape as the Stop hook's block counter (ADR-0008): read, bump,
# clear on success, refuse above the maximum. Same pattern, same ceiling of
# three, not a second implementation of the idea. Created lazily -- a project
# with no .claude/ should not acquire one just by being driven.
STATE_DIR="${AUTOPILOT_STATE_DIR:-$ROOT/.claude/.hook-state}"

# Which skill reference to hand the worker. devseed mirrors its skills into
# .claude/skills/ precisely so it runs the working tree's copy rather than the
# stale installed plugin (ADR-0016) -- an installed copy is pinned at install
# time and has sat eleven commits behind HEAD before now. Driving the installed
# copy would reintroduce exactly that. Consumers, who have no mirror, get the
# namespaced form.
if [ -n "${AUTOPILOT_TASK_SKILL:-}" ]; then
  TASK_SKILL="$AUTOPILOT_TASK_SKILL"
elif [ -f "$ROOT/.claude/skills/task/SKILL.md" ]; then
  TASK_SKILL="/task"
else
  TASK_SKILL="/governed-dev:task"
fi

# ---------------------------------------------------------------------------
# Task selection
# ---------------------------------------------------------------------------

# First `## T-NNN` whose Status field begins `todo`, top to bottom.
#
# TODO(spec): SG-0013 -- the status vocabulary cannot say "todo, but not
# unattended". T-022 reads `todo — **optional**, may never be built`, so it is
# what a no-argument run picks first. Matching only the first word is the
# stated assumption; parsing the prose after it would invent a convention the
# ledger never declared. Give explicit ids until SG-0013 is settled.
next_todo() {
  awk '
    /^## T-[0-9]+/       { id = $2; have = 1; next }
    have && /^- \*\*Status:\*\*/ {
      s = $0
      sub(/^- \*\*Status:\*\*[ \t]*/, "", s)
      if (s ~ /^todo/) { print id; exit }
      have = 0
    }
  ' TASKS.md
}

task_status() {
  awk -v want="$1" '
    /^## T-[0-9]+/       { id = $2; have = (id == want); next }
    have && /^- \*\*Status:\*\*/ {
      s = $0
      sub(/^- \*\*Status:\*\*[ \t]*/, "", s)
      print s; exit
    }
  ' TASKS.md
}

# ---------------------------------------------------------------------------
# Evidence gathering. Every function here reads the REPOSITORY. None of them
# reads the worker's opinion of the repository.
# ---------------------------------------------------------------------------

# The SG ids currently on record.
#
# FORMAT DEPENDENCY, stated so the next migration finds it: since ADR-0029 each
# ADR is its own file under docs/adr/, but the "Spec gaps observed" section
# stays INLINE in DECISIONS.md and hand-written, deliberately -- gaps are meant
# to be one short uncomfortable visible list. This function therefore reads
# DECISIONS.md, and it reads it under either layout. If a later task ever moves
# spec gaps into their own files, this is the line that changes.
sg_ids() {
  sed -n 's/^#\{2,4\} *\(SG-[0-9]\{4\}\).*/\1/p' DECISIONS.md 2>/dev/null | sort -u
}

# One SG entry, reduced to what a human needs to rule on it.
sg_summary() {
  awk -v id="$1" '
    $0 ~ "^#+ *" id { on = 1; print; next }
    on && /^#{2,4} /                { exit }
    on && /^\*\*Assumed:\*\*/       { print; found = 1; next }
    on && found && /^$/             { exit }
    on && found                     { print }
  ' DECISIONS.md 2>/dev/null | head -8
}

# The commit that carries this task, from the repository rather than from a
# report of it. Two ways it can be recorded, and either satisfies:
#
#   1. a commit trailered `Task-Id: T-NNN` -- what /task writes on the commit
#      it makes (T-027, ADR-0022). This is the normal case, because /task
#      deliberately leaves the task `in-progress`: a commit cannot contain its
#      own hash, so TASKS.md catches up on the NEXT commit. Requiring
#      `done` + hash here would mean autopilot could never see agreement.
#   2. TASKS.md marking it `done` with a hash that resolves -- check 5's own
#      test, applied to one task.
#
# Prints the hash, or nothing. Nothing means the repository holds no evidence
# this task happened, which is never agreement however cleanly the worker
# reported (this is the routing rule the two hand-carried failures came from).
task_commit() {
  local t="$1" h
  h="$(git log -E --grep="^Task-Id: ${t}\$" --format='%h' "$BASE_HEAD..HEAD" 2>/dev/null | head -1)"
  if [ -z "$h" ]; then
    local st
    st="$(task_status "$t")"
    case "$st" in
      done*)
        h="$(awk -v want="$t" '
          /^## T-[0-9]+/ { have = ($2 == want); next }
          have && /^- \*\*Commit:\*\*/ {
            if (match($0, /`[0-9a-f]{7,40}`/)) {
              print substr($0, RSTART + 1, RLENGTH - 2); exit
            }
          }' TASKS.md)"
        [ -n "$h" ] && [ "$(git cat-file -t "$h" 2>/dev/null)" = commit ] || h=""
        ;;
    esac
  fi
  printf '%s' "$h"
}

# ---------------------------------------------------------------------------
# The disagreement patterns.
#
# These are HEURISTICS over the worker's prose, and they are the least certain
# part of this script. They are tuned to over-stop: a false stop costs a human
# one minute of reading a report entry, a false continue costs whatever the
# next tasks build on an unnoticed spec question. Named in ADR-0030 as a known
# limit rather than presented as detection.
# ---------------------------------------------------------------------------
AMEND_RE='(^|[^a-z])/(governed-dev:)?amend([^a-z]|$)|\bamendment\b|\bamend DESIGN\.md\b|DESIGN\.md §6'
ASK_RE='\bCONFLICT\b|blocking GAP|needs? a human|human (decision|approval|to decide)|cannot proceed|which (of|one) (do|should) you|please (confirm|decide|choose)'
QUESTION_RE='\?[[:space:]]*$'

matched_lines() {   # regex, text -> up to 3 matching lines
  printf '%s\n' "$2" | grep -nE "$1" 2>/dev/null | head -3
}

# ---------------------------------------------------------------------------
# The worker's argv. Built in exactly one place so the assertion below can see
# all of it.
#
# NO PERMISSION FLAGS. Not --dangerously-skip-permissions, not
# --permission-mode, not --allowedTools. The worker gets what the interactive
# /task flow gets. If a prompt blocks headless execution the run fails and the
# failure is reported as a finding; loosening the allowlist to make automation
# smoother would make autopilot a hole in the boundary rather than a driver
# above it. This assertion exists because that edit is the tempting one, and it
# would look like a convenience.
# ---------------------------------------------------------------------------
assert_no_widening() {
  local a
  for a in "$@"; do
    case "$a" in
      --dangerously-skip-permissions|--permission-mode|--allowedTools|\
      --allowed-tools|--disallowedTools|--add-dir|--settings)
        printf 'AUTOPILOT BUG: worker argv contains %s.\n' "$a" >&2
        printf 'The worker runs with the interactive flow'"'"'s permissions and no more.\n' >&2
        printf 'A permission prompt that blocks headless execution is a finding to\n' >&2
        printf 'report, not a setting to loosen. Revert the edit that added this.\n' >&2
        exit 2
        ;;
    esac
  done
}

TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN="timeout"

run_worker() {   # prompt -> sets W_RC W_OUT W_ERR
  local prompt="$1"
  local -a argv
  argv=( -p "$prompt" --output-format json --max-turns "$MAX_TURNS" )
  assert_no_widening "${argv[@]}"

  local errf; errf="$WORK/worker.err"
  if [ -n "$TIMEOUT_BIN" ]; then
    W_OUT="$("$TIMEOUT_BIN" "$TASK_TIMEOUT" "$CLAUDE_BIN" "${argv[@]}" 2>"$errf")"
  else
    W_OUT="$("$CLAUDE_BIN" "${argv[@]}" 2>"$errf")"
  fi
  W_RC=$?
  W_ERR="$(cat "$errf" 2>/dev/null)"
}

# ---------------------------------------------------------------------------
# The report. The whole point: what the human sees.
# ---------------------------------------------------------------------------
WORK="$(mktemp -d "${TMPDIR:-/tmp}/devseed-autopilot.XXXXXX")" || refuse "cannot create a scratch directory."
trap 'rm -rf "$WORK"' EXIT
: > "$WORK/decisions"
: > "$WORK/digest"
: > "$WORK/ledger"

DECISION_N=0
TOTAL_COST=0
TASKS_DONE=0
STOP_REASON=""

add_cost() { TOTAL_COST="$(awk -v a="$TOTAL_COST" -v b="$1" 'BEGIN { printf "%.4f", a + b }')"; }
over_ceiling() { awk -v a="$1" -v b="$COST_CEILING" 'BEGIN { exit !(a > b) }'; }

# decision <task> <kind> <what the documents say> <what the repo/worker says> <the delta>
#
# Structure is fixed and the fields are the argument: a disagreement entry a
# human cannot act on in under a minute of reading is a badly written entry.
# No transcripts. No narration. Hashes, not re-explained diffs -- git already
# shows the diff and shows it better.
decision() {
  DECISION_N=$((DECISION_N + 1))
  {
    printf '\n### %d. %s — %s\n\n' "$DECISION_N" "$1" "$2"
    printf '**What the documents say**\n\n%s\n\n' "$3"
    printf '**What the repository says**\n\n%s\n\n' "$4"
    printf '**The delta**\n\n%s\n\n' "$5"
    printf '**Options** — pick one:\n\n'
    printf '1. Approve the SG resolution (settle the gap, then re-run this task).\n'
    printf '2. Approve the amendment (`/amend` executes §6; autopilot never does).\n'
    printf '3. Reject and re-spec (rewrite the task; the assumption was wrong).\n'
    printf '4. Take over manually (`%s %s` interactively).\n' "$TASK_SKILL" "$1"
  } >> "$WORK/decisions"
}

write_report() {
  mkdir -p reports 2>/dev/null || { say "cannot create reports/"; return 1; }
  local base n
  base="reports/autopilot-$(date +%Y-%m-%d)"
  REPORT="$base.md"
  n=2
  # Never overwrite an earlier report: it may be a decision queue nobody has
  # read yet, and a destroyed queue is worse than no queue.
  while [ -e "$REPORT" ]; do REPORT="$base-$n.md"; n=$((n + 1)); done

  {
    printf '# Autopilot run — %s\n\n' "$(date '+%Y-%m-%d %H:%M')"
    printf -- '- **Branch:** `%s`  ·  **Started from:** `%s`  ·  **Run cap:** %s task(s)\n' \
      "$BRANCH" "$(git rev-parse --short "$BASE_HEAD")" "$MAX_TASKS"
    printf -- '- **Stop reason:** %s\n\n' "${STOP_REASON:-queue exhausted}"
    printf '> **Legend.** Everything under COMPLETED WITHOUT YOU passed the gate\n'
    printf '> unattended. The gate checks *structural* agreement, not semantic\n'
    printf '> agreement, and checks 1–3 pass vacuously in a project that declares no\n'
    printf '> build, tests or linter (DESIGN.md §5, Known limits). A green gate is\n'
    printf '> therefore evidence that nothing DISAGREED, not proof the work is right.\n'
    printf '> The digest exists so those tasks stay visible without being blocking —\n'
    printf '> it is the mitigation for that limit, not a claim the limit is gone.\n'

    if [ -s "$WORK/decisions" ]; then
      printf '\n## DECISIONS NEEDED\n'
      printf '\n%s stopped the loop. Nothing below has been acted on.\n' \
        "$( [ "$DECISION_N" = 1 ] && printf 'One disagreement' || printf '%s disagreements' "$DECISION_N" )"
      cat "$WORK/decisions"
      printf '\n'
    fi

    printf '\n## COMPLETED WITHOUT YOU\n\n'
    if [ -s "$WORK/digest" ]; then
      printf '| task | what landed | commit | cost |\n|---|---|---|---|\n'
      cat "$WORK/digest"
    else
      printf 'Nothing. No task reached agreement this run.\n'
    fi

    printf '\n## RUN LEDGER\n\n'
    printf '| task | session | attempts | cost (USD) | verdict |\n|---|---|---|---|---|\n'
    cat "$WORK/ledger"
    printf '\n- **Total cost:** $%s across %s task(s)\n' "$TOTAL_COST" "$TASKS_DONE"
    printf -- '- **Commits made:** `%s..%s`\n' \
      "$(git rev-parse --short "$BASE_HEAD")" "$(git rev-parse --short HEAD)"
    local leftover
    leftover="$(git status --porcelain 2>/dev/null | grep -v '^?? reports/' | wc -l | tr -d ' ')"
    [ "$leftover" = 0 ] || printf -- '- **Uncommitted changes left in the tree:** %s path(s). Autopilot did not clean up after a stop; the evidence is worth more than a tidy tree.\n' "$leftover"
  } > "$REPORT"

  # Commit the report, and ONLY the report. Pathspec-limited so a stop that
  # left the worker's changes in the tree does not sweep them into a commit
  # nobody reviewed. /task remains the only thing that commits work; this
  # commits one artifact, its own account of the run (ADR-0030).
  git add -- "$REPORT" >/dev/null 2>&1
  git commit -q -m "autopilot: run report $(date +%Y-%m-%d) (${STOP_REASON:-queue exhausted})" \
    -m "$DECISION_N decision(s) needed, $TASKS_DONE task(s) completed unattended." \
    -m "Agent-Type: autopilot
Autopilot-Run: $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -- "$REPORT" >/dev/null 2>&1 || say "the report was written but could not be committed."

  printf '%s\n' "$REPORT"
}

# ---------------------------------------------------------------------------
# The loop
# ---------------------------------------------------------------------------

BASE_HEAD="$(git rev-parse HEAD)"
SG_BEFORE="$(sg_ids)"

QUEUE="$TASK_IDS"
EXPLICIT=0
FIRST=""
if [ -n "$QUEUE" ]; then
  EXPLICIT=1
else
  FIRST="$(next_todo)"
  [ -n "$FIRST" ] || { say "no task with status \`todo\` in TASKS.md. Nothing to do."; exit 0; }
fi

if [ "$DRY_RUN" = 1 ]; then
  say "preflight passed on branch $BRANCH at $(git rev-parse --short HEAD)."
  if [ "$EXPLICIT" = 1 ]; then
    say "queue (explicit):$QUEUE"
  else
    say "queue (first todo, re-read after each task): $FIRST"
  fi
  say "worker: $CLAUDE_BIN -p \"$TASK_SKILL <id>\" --output-format json --max-turns $MAX_TURNS"
  say "--dry-run: stopping before the first worker. No report written."
  exit 0
fi

ATTEMPTED=""

while : ; do
  if [ "$TASKS_DONE" -ge "$MAX_TASKS" ]; then
    STOP_REASON="run cap reached ($MAX_TASKS task(s) per invocation)"
    break
  fi

  # Pick.
  if [ "$EXPLICIT" = 1 ]; then
    set -- $QUEUE
    [ $# -gt 0 ] || { STOP_REASON="explicit queue exhausted"; break; }
    T="$1"; shift; QUEUE="$*"
  else
    T="$(next_todo)"
    [ -n "$T" ] || { STOP_REASON="queue exhausted (no task left with status \`todo\`)"; break; }
  fi

  case " $ATTEMPTED " in
    *" $T "*)
      # The picker returned a task this run already attempted, which means the
      # ledger did not move. Fail closed rather than loop.
      STOP_REASON="$T still reads \`todo\` after an attempt"
      decision "$T" "drift/failure" \
"TASKS.md's conventions: a task moves \`todo\` → \`in-progress\` → \`done\`, and /task leaves it \`in-progress\` on the commit that does the work." \
"$T still reads \`$(task_status "$T")\` after autopilot ran it, so the picker would return it again forever." \
"The worker either did not run the task or did not record it. Autopilot stopped rather than re-picking the same task in a loop."
      break
      ;;
  esac
  ATTEMPTED="$ATTEMPTED $T"

  STRIKE_F="$STATE_DIR/autopilot-strikes-$T"
  STRIKES=0
  [ -f "$STRIKE_F" ] && STRIKES="$(cat "$STRIKE_F" 2>/dev/null)"
  case "$STRIKES" in ''|*[!0-9]*) STRIKES=0 ;; esac

  if [ "$STRIKES" -ge "$MAX_STRIKES" ]; then
    STOP_REASON="$T has used all $MAX_STRIKES strikes"
    # No `ADR-NNNN` id appears in any report text, here or below. A report is
    # committed into the repository it describes, and every citation-resolving
    # check reads every tracked file: an id that means something in devseed and
    # nothing here would fail this repository's own orphan check. Sections and
    # filenames travel; numbers do not.
    decision "$T" "drift/failure" \
"DESIGN.md §5: the gate is the definition of done, and a check that cannot run is a failed check. The Stop hook set the precedent that a mechanism which cannot be satisfied escalates to the human rather than retrying forever." \
"$T has now failed the gate $STRIKES times across runs. The counter is at \`$STRIKE_F\`." \
"This task is not autopilot's to finish. The circuit breaker opened rather than spending a fourth attempt on a failure that has survived three."
    break
  fi

  say "task $T (strike count $STRIKES, $TASKS_DONE/$MAX_TASKS done this run)"

  PROMPT="$TASK_SKILL $T"
  ATTEMPTS=0
  VERDICT=""
  T_COST=0
  SESSIONS=""

  while : ; do
    ATTEMPTS=$((ATTEMPTS + 1))
    run_worker "$PROMPT"

    # Parse leniently first. A worker that failed may still have said something
    # structured, and taking its session id off a failed run costs nothing and
    # is what makes the run ledger joinable to .claude/activity.jsonl later.
    SESSION=""; COST=0; IS_ERR=false; SUBTYPE=""; RESULT=""; PARSED=0
    if printf '%s' "$W_OUT" | jq -e 'type == "object"' >/dev/null 2>&1; then
      PARSED=1
      SESSION="$(printf '%s' "$W_OUT" | jq -r '.session_id // "unknown"')"
      COST="$(printf '%s' "$W_OUT" | jq -r '.total_cost_usd // 0')"
      IS_ERR="$(printf '%s' "$W_OUT" | jq -r '.is_error // false')"
      SUBTYPE="$(printf '%s' "$W_OUT" | jq -r '.subtype // ""')"
      RESULT="$(printf '%s' "$W_OUT" | jq -r '.result // ""')"
      SESSIONS="$SESSIONS${SESSIONS:+, }\`$SESSION\`"
      T_COST="$(awk -v a="$T_COST" -v b="$COST" 'BEGIN { printf "%.4f", a + b }')"
    fi

    # --- (d): the worker itself failed or timed out. Checked before the JSON,
    # because a nonzero exit is unambiguous and says more than "no output did".
    if [ "$W_RC" != 0 ]; then
      VERDICT="worker exit $W_RC"
      STOP_REASON="$T: the worker exited $W_RC${SUBTYPE:+ ($SUBTYPE)}"
      decision "$T" "worker/failed" \
"DESIGN.md §5: a check that cannot run is a failed check. The same rule applied to the worker: a task whose runner did not complete has not been verified by anything." \
"\`$CLAUDE_BIN\` exited $W_RC$( [ "$W_RC" = 124 ] && printf ' (the %ss wall clock was exceeded)' "$TASK_TIMEOUT" )${SESSION:+, session \`$SESSION\`}.
$( [ -n "$W_ERR" ] && printf '\nstderr:\n\n```\n%s\n```\n' "$(printf '%s' "$W_ERR" | tail -20)" )" \
"$( [ "$W_RC" = 124 ] && printf 'The task did not finish inside its time bound. Raise --timeout if the task is genuinely long, or split it.' || printf 'Whatever the worker did or did not do, the repository holds no verdict for it. Autopilot stopped rather than assuming one.' )"
      break
    fi

    # --- (d): a verdict that cannot be read is not a verdict. Order in the
    # routing rules is about which DISAGREEMENT wins; an unreadable result is
    # not a disagreement, it is an absence of one.
    if [ "$PARSED" = 0 ]; then
      VERDICT="unreadable"
      STOP_REASON="$T: the worker's output was not JSON autopilot could read"
      decision "$T" "worker/unreadable" \
"This script's own rule, stated in its header: an autopilot that cannot read its worker's verdict does not guess." \
"\`$CLAUDE_BIN\` exited $W_RC and its output did not parse as a JSON object. First 200 characters:

\`\`\`
$(printf '%s' "$W_OUT" | head -c 200)
\`\`\`
$( [ -n "$W_ERR" ] && printf '\nstderr:\n\n```\n%s\n```\n' "$(printf '%s' "$W_ERR" | tail -20)" )" \
"No verdict was produced, so nothing was routed. If this is a permission prompt blocking headless execution, that is the finding — autopilot will not widen an allowlist to get past it."
      break
    fi

    # --- (d): the worker reported its own failure.
    if [ "$IS_ERR" = true ]; then
      VERDICT="worker error"
      STOP_REASON="$T: the worker reported an error (${SUBTYPE:-no subtype})"
      decision "$T" "worker/failed" \
"DESIGN.md §5: a check that cannot run is a failed check. The same rule applied to the worker: a task whose runner did not complete has not been verified by anything." \
"The worker returned \`is_error: true\`, subtype \`$SUBTYPE\`, session \`$SESSION\`:

\`\`\`
$(printf '%s' "$RESULT" | head -20)
\`\`\`" \
"If this is a permission prompt blocking headless execution, that is the finding — autopilot runs the worker with the interactive flow's permissions and will not widen an allowlist to get past one."
      break
    fi

    if over_ceiling "$T_COST"; then
      VERDICT="cost ceiling"
      STOP_REASON="$T: per-task cost ceiling of \$$COST_CEILING exceeded"
      decision "$T" "budget" \
"This script's run bounds: a per-task cost ceiling of \$$COST_CEILING, set in its config block and overridable by --cost-ceiling." \
"$T cost \$$T_COST across $ATTEMPTS attempt(s)." \
"The ceiling is a bound on autonomy, not a judgement about the task. Raise it deliberately with --cost-ceiling, or run this task interactively."
      break
    fi

    # --- Evidence, gathered from the repository.
    GATE_ERR="$(CLAUDE_PROJECT_DIR="$ROOT" bash "$GATE" 2>&1 >/dev/null)"
    GATE_RC=$?
    SG_AFTER="$(sg_ids)"
    NEW_SG="$(printf '%s\n' "$SG_AFTER" | grep -vxF -f <(printf '%s\n' "$SG_BEFORE") 2>/dev/null | grep -E '^SG-[0-9]{4}$')"
    DESIGN_TOUCHED="$( { git diff --name-only "$BASE_HEAD..HEAD" 2>/dev/null; git status --porcelain 2>/dev/null | awk '{print $2}'; } | grep -x 'DESIGN.md' | head -1 )"
    AMEND_HIT="$(matched_lines "$AMEND_RE" "$RESULT")"
    ASK_HIT="$(matched_lines "$ASK_RE" "$RESULT")"
    Q_HIT="$(matched_lines "$QUESTION_RE" "$RESULT")"
    HASH="$(task_commit "$T")"

    # --- (a) AGREEMENT ------------------------------------------------------
    # Gate 0, no new SG, nothing amend-shaped, no question, and the repository
    # holds this task's commit. Every clause is checked against the repository.
    if [ "$GATE_RC" = 0 ] && [ -z "$NEW_SG" ] && [ -z "$DESIGN_TOUCHED" ] \
       && [ -z "$AMEND_HIT" ] && [ -z "$ASK_HIT" ] && [ -z "$Q_HIT" ] && [ -n "$HASH" ]; then
      VERDICT="agreement"
      rm -f "$STRIKE_F" 2>/dev/null
      # The commit subject IS the one-sentence summary, written by the worker
      # that did the work and already reviewed by the gate. Restating it here
      # would be a second account of the same thing, drifting from the first.
      printf '| %s | %s | `%s` | $%s |\n' \
        "$T" "$(git log -1 --format=%s "$HASH" | sed 's/|/\\|/g')" "$HASH" "$T_COST" \
        >> "$WORK/digest"
      break
    fi

    # --- (b) DISAGREEMENT, spec kind ---------------------------------------
    # Checked before the gate's own failure: a spec question that also broke
    # the gate is still a spec question, and retrying it would be asking the
    # worker to answer something only the human can.
    if [ -n "$NEW_SG" ] || [ -n "$DESIGN_TOUCHED" ] || [ -n "$AMEND_HIT" ] || [ -n "$ASK_HIT" ] || [ -n "$Q_HIT" ]; then
      VERDICT="disagreement (spec)"
      if [ -n "$NEW_SG" ]; then
        STOP_REASON="$T: new spec gap recorded ($(printf '%s' "$NEW_SG" | tr '\n' ' '))"
        decision "$T" "spec gap" \
"\`.claude/rules/ambiguity.md\`: where DESIGN.md is silent, record the gap — never invent past it. A recorded gap is a guess until a human confirms it." \
"The worker recorded a new entry while doing $T:

$(for id in $NEW_SG; do sg_summary "$id"; printf '\n'; done)" \
"DESIGN.md does not cover this and now something is built on the assumption above. Autopilot will not resolve an SG entry — that is §6's allocation, and it is the wall this feature is built against."
      elif [ -n "$DESIGN_TOUCHED" ]; then
        STOP_REASON="$T: DESIGN.md was modified"
        decision "$T" "amendment" \
"DESIGN.md §6: amendments go ADR first, then explicit human approval, then the edit — and \`/amend\` is the sole sanctioned route. Autopilot never touches DESIGN.md." \
"DESIGN.md was modified during $T. Diff: \`git diff $(git rev-parse --short "$BASE_HEAD")..HEAD -- DESIGN.md\`" \
"The constitution changed without the procedure that authorises changing it. This stops the loop unconditionally, whatever the gate said."
      elif [ -n "$AMEND_HIT" ]; then
        STOP_REASON="$T: the worker proposed something /amend-shaped"
        decision "$T" "amendment proposed" \
"DESIGN.md §6: agents draft and propose; the human decides, explicitly, before anything is edited. \`/amend\` executes the procedure and refuses to run it out of order." \
"The worker's report on $T (session \`$SESSION\`) contains:

\`\`\`
$AMEND_HIT
\`\`\`" \
"A proposed amendment is a proposal, and it stays one until a human approves it. Run \`/amend\` yourself if the proposal has merit."
      else
        STOP_REASON="$T: the worker asked the human a question"
        decision "$T" "question" \
"\`.claude/rules/ambiguity.md\`: asking is preferred when the answer changes what gets built. The whole design leans on asking the human being cheap (DESIGN.md §2)." \
"The worker's report on $T (session \`$SESSION\`) contains:

\`\`\`
$( [ -n "$ASK_HIT" ] && printf '%s\n' "$ASK_HIT"; [ -n "$Q_HIT" ] && printf '%s\n' "$Q_HIT" )
\`\`\`" \
"Nobody was there to answer it. The loop stopped so the question reaches you before anything is built on a guessed answer."
      fi
      break
    fi

    # --- (c) DISAGREEMENT, drift/failure kind ------------------------------
    if [ "$GATE_RC" = 2 ]; then
      STRIKES=$((STRIKES + 1))
      mkdir -p "$STATE_DIR" 2>/dev/null
      printf '%s' "$STRIKES" > "$STRIKE_F" 2>/dev/null

      if [ "$ATTEMPTS" = 1 ] && [ "$STRIKES" -lt "$MAX_STRIKES" ]; then
        # Failure messages are instructions (DESIGN.md §5), so let them
        # instruct — once. A second identical failure means the instruction
        # did not land, and repeating it is the loop being routed around.
        say "$T: gate exit 2. Retrying once with the gate's findings appended."
        PROMPT="$TASK_SKILL $T

The gate failed after the previous attempt. Its findings, verbatim:

$GATE_ERR

Fix exactly these. Do not work around the gate — it is the definition of done
(DESIGN.md §5), and its messages name the file and the action to take. If the
failure is not yours to fix, say so plainly and stop."
        continue
      fi

      VERDICT="disagreement (gate)"
      STOP_REASON="$T: gate exit 2 after $ATTEMPTS attempt(s)"
      decision "$T" "gate failure" \
"DESIGN.md §5: exit 0 is pass, exit 2 is fail, and a check that cannot run is a failed check. The gate is the single definition of done and autopilot is a consumer of its verdict, never a second opinion on it." \
"The gate exits 2 on the tree $T left behind, after $ATTEMPTS attempt(s) — the second with the findings appended to the prompt. Findings:

\`\`\`
$(printf '%s' "$GATE_ERR" | tail -25)
\`\`\`" \
"Strike $STRIKES of $MAX_STRIKES for this task. The worker was handed the gate's own instructions and the gate still refuses the result."
      break
    fi

    # --- (d) anything else --------------------------------------------------
    VERDICT="unrouted"
    STOP_REASON="$T: gate exit $GATE_RC with no commit recorded for the task"
    decision "$T" "unrouted" \
"This script's routing rules: agreement requires the gate at 0 AND the task's commit present in the repository. Anything that matches no rule stops the loop — autopilot fails closed." \
"Gate exit $GATE_RC. $( if [ -z "$HASH" ]; then printf 'No commit in `%s..HEAD` carries `Task-Id: %s`, and TASKS.md does not mark %s done with a resolving hash.' "$(git rev-parse --short "$BASE_HEAD")" "$T" "$T"; else printf 'The task is recorded at `%s`, but the gate did not return 0 or 2.' "$HASH"; fi )" \
"The worker's own account may say the task is finished. The repository does not say so, and the repository is what autopilot routes on — that disagreement is the exact failure this script exists to catch."
    break
  done

  add_cost "$T_COST"
  printf '| %s | %s | %s | %s | %s |\n' \
    "$T" "${SESSIONS:-—}" "$ATTEMPTS" "$T_COST" "$VERDICT" >> "$WORK/ledger"

  if [ "$VERDICT" = "agreement" ]; then
    TASKS_DONE=$((TASKS_DONE + 1))
    SG_BEFORE="$(sg_ids)"
    continue
  fi
  break
done

REPORT=""
write_report >/dev/null
[ -n "$REPORT" ] || REPORT="$(ls -1t reports/autopilot-*.md 2>/dev/null | head -1)"

printf '\n'
if [ "$DECISION_N" -gt 0 ]; then
  printf 'AUTOPILOT STOPPED: %s\n' "$STOP_REASON" >&2
  printf '%s decision(s) need you. %s task(s) completed unattended.\n' "$DECISION_N" "$TASKS_DONE" >&2
else
  printf 'AUTOPILOT DONE: %s\n' "$STOP_REASON" >&2
  printf '%s task(s) completed unattended, no decisions needed.\n' "$TASKS_DONE" >&2
fi
printf '%s\n' "$REPORT"

[ "$DECISION_N" = 0 ] || exit 2
exit 0
