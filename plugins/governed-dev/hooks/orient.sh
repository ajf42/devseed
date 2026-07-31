#!/usr/bin/env bash
#
# orient.sh -- SessionStart. Hands a fresh session the state it would otherwise
# have to go and find, as additionalContext.
#
# The point is not convenience. A session that has to reconstruct where it is
# reconstructs it by inference, and inference across a stale CLAUDE.md, a
# half-updated TASKS.md and a dirty tree is exactly how an invented constraint
# gets its start. So this reports the three sources SEPARATELY and, when they
# disagree, says so and refuses to pick a winner -- that call belongs to the
# human, per .claude/rules/precedence.md.
#
# Exit 2 here does NOT block anything; SessionStart failures are reported and
# the session continues. Fail visibly, never silently.
HOOK_NAME="SessionStart/orient"
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! have_jq; then
  hook_jq_advice >&2
  hook_die "cannot emit additionalContext without jq; this session starts unoriented."
fi

ROOT="$(hook_root)"
cd "$ROOT" 2>/dev/null || hook_die "cannot enter $ROOT."

git rev-parse --git-dir >/dev/null 2>&1 || {
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"orient.sh: not a git repository, so no project state could be read."}}'
  exit 0
}

# Record the HEAD this session started at. SessionEnd/SubagentStop diff against
# it to report the commits the session actually made.
_state="$(hook_state_dir)" && [ -n "$_state" ] &&
  git rev-parse HEAD >"$_state/head-$(hook_session_slug)" 2>/dev/null

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
STATUS="$(git status --short 2>/dev/null)"
COMMITS="$(git log -5 --format='%h %s' 2>/dev/null)"

# --- next task -------------------------------------------------------------
# The first "## T-NNN" block carrying no resolved commit hash. That is what is
# in flight: TASKS.md's convention is that a task stays open until a LATER
# commit records both its status and its hash, so "no hash" is the honest
# marker of unfinished, and "done" is not.
NEXT="$(awk '
  /^## T-[0-9]+/ { if (id != "" && !hash) { print id " — " title; exit }
                   id=$2; title=$0; sub(/^## T-[0-9]+[^A-Za-z0-9]*/,"",title); hash=0; status="?" }
  /^- \*\*Commit:\*\*.*`[0-9a-f]{7}/ { hash=1 }
  /^- \*\*Status:\*\*/ { s=$0; sub(/^- \*\*Status:\*\* */,"",s); status=s }
  END { if (id != "" && !hash) print id " — " title }
' TASKS.md 2>/dev/null | head -1)"
[ -n "$NEXT" ] || NEXT="(none found — TASKS.md is missing, empty, or every task carries a hash)"

# --- working memory freshness ----------------------------------------------
_src_t="$(git log -1 --format=%ct -- src/ 2>/dev/null)"
_cm_t="$(git log -1 --format=%ct -- CLAUDE.md 2>/dev/null)"
if [ -z "$_src_t" ]; then
  MEMSTATE="no commit has touched src/ — gate check 4 has nothing to compare against."
elif [ -z "$_cm_t" ]; then
  MEMSTATE="STALE: src/ has been committed but CLAUDE.md never has."
elif [ "$_src_t" -gt "$_cm_t" ]; then
  MEMSTATE="STALE: the last commit touching src/ is newer than the last commit touching CLAUDE.md. Working memory describes an older tree than the code."
else
  MEMSTATE="current: CLAUDE.md was committed no earlier than the last src/ change."
fi

# --- disagreement detection -------------------------------------------------
# Three sources claim to describe project state: TASKS.md, the filesystem, and
# git log. Where they conflict, say so. Do not reconcile.
DISAGREE=""
add_d() { DISAGREE="${DISAGREE}  - $1
"; }

# Ledger vs git: a task claiming done must name a commit that exists.
while IFS= read -r _t; do
  [ -n "$_t" ] || continue
  _id="${_t%%|*}"; _h="${_t##*|}"
  if [ -z "$_h" ]; then
    add_d "TASKS.md marks $_id done with no commit hash. git cannot confirm it happened."
  elif ! git cat-file -t "$_h" >/dev/null 2>&1; then
    add_d "TASKS.md marks $_id done at \`$_h\`, which does not resolve to an object in this repository."
  fi
done <<EOF
$(awk '
  /^## T-[0-9]+/ { if (id != "" && st ~ /done/) print id "|" h; id=$2; st=""; h="" }
  /^- \*\*Status:\*\*/ { st=$0 }
  /^- \*\*Commit:\*\*/ { h=$0; if (match(h, /`[0-9a-f]{7,}`/)) h=substr(h, RSTART+1, RLENGTH-2); else h="" }
  END { if (id != "" && st ~ /done/) print id "|" h }
' TASKS.md 2>/dev/null)
EOF

# Filesystem vs ledger: work in the tree that no task claims to be doing.
# `grep -c` prints its count AND exits 1 when the count is zero, so a
# `|| printf 0` fallback appends a second zero and yields "00" -- which compares
# equal to nothing and silently disabled this check. Normalise instead.
_inprog="$(grep -c '^- \*\*Status:\*\* *in-progress' TASKS.md 2>/dev/null)"
case "$_inprog" in ''|*[!0-9]*) _inprog=0 ;; esac
if [ -n "$STATUS" ] && [ "$_inprog" = "0" ]; then
  add_d "The working tree is dirty but no task is marked in-progress. Either the ledger was not updated, or these edits belong to no task."
fi
[ "${_inprog:-0}" -gt 1 ] 2>/dev/null &&
  add_d "$_inprog tasks are marked in-progress at once. TASKS.md's convention is one task per commit."

# A prior session compacted and may have been cut off mid-task.
if [ -f "$ROOT/.claude/in-flight.md" ]; then
  add_d "An in-flight snapshot exists at .claude/in-flight.md, written by the PreCompact hook. A previous session was compacted mid-task; read it before assuming that task finished."
fi

# --- assemble ---------------------------------------------------------------
CTX="$(cat <<EOF
## Session orientation (SessionStart hook, generated — not written by hand)

**Branch:** ${BRANCH:-unknown}

**Uncommitted changes (git status --short):**
${STATUS:-  (clean)}

**Last 5 commits:**
${COMMITS:-  (none)}

**First task with no recorded commit hash:**
  $NEXT

**Working memory (CLAUDE.md) vs src/:** $MEMSTATE

EOF
)"

if [ -n "$DISAGREE" ]; then
  CTX="$CTX
### STATE DISAGREEMENT — do not resolve this by inference

TASKS.md, the filesystem, and git log do not agree about what has happened:

$DISAGREE
These are not necessarily errors, and they are not yours to reconcile silently.
Surface the disagreement to the human, quote what each source claims, and ask
which is wrong before you build on either. Per .claude/rules/precedence.md,
editing one record to match the other buries a decision that is the human's to
make."
else
  CTX="$CTX
TASKS.md, the filesystem, and git log agree on project state."
fi

jq -n --arg c "$CTX" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
exit 0
