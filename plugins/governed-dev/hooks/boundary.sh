#!/usr/bin/env bash
#
# boundary.sh -- PreToolUse on Edit|Write. Denies a write that crosses the
# writing agent's boundary.
#
# This is the mechanism ADR-0007 says the agent roster exists for. An agent's
# `tools:` allowlist gates WHICH TOOLS it holds, not WHICH FILES it may touch,
# so "the implementer cannot write DECISIONS.md" is documentation until this
# hook denies it. The failure being prevented is specific: an agent that hits a
# spec wall resolving the wall by editing the document that defines it, then
# continuing. A rule an agent can edit its way around is advice.
#
# Exit 2 here blocks the tool call, but a JSON deny is preferred: it carries a
# reason the agent reads and acts on. JSON is only honoured on exit 0.
HOOK_NAME="PreToolUse/boundary"
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# A boundary that cannot evaluate itself is not a boundary. Without jq this
# script cannot read agent_type, so it cannot tell an implementer from a
# read-only auditor -- and the safe reading of "unknown agent" at an
# enforcement point is not "allow". Blocks loudly with the fix.
if ! have_jq; then
  { hook_jq_advice
    printf '\nUntil then every Edit and Write is blocked, because this hook\n'
    printf 'cannot tell which agent is writing and will not guess at an\n'
    printf 'enforcement point.\n'
  } >&2
  hook_die "cannot evaluate agent boundaries without jq."
fi

AGENT="$(hook_agent_type)"
# NotebookEdit carries notebook_path, not file_path. A boundary that reads only
# file_path is a boundary with a documented way around it.
FILE="$(hook_field '.tool_input.file_path // .tool_input.notebook_path')"
TOOL="$(hook_field '.tool_name')"

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",
    permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# The spec-gap marker template, assembled at runtime so quoting it inside a deny
# message does not trip gate check 6 -- which greps changed files for the
# literal token and, finding "SG-NNNN", correctly reports an untraceable marker.
# Same idiom, and the same reason, as gates/check-06-spec-gaps.sh.
_MARK="TODO"; _MARK="${_MARK}(spec): SG-NNNN"

# TODO(spec): SG-0005 — DESIGN.md and T-007 define boundaries per agent but say
# nothing about the main session thread, which carries no agent_type at all.
# Assumed: absent agent_type means the top-level session, which has no declared
# boundary and is allowed. Denying instead would make the project unwritable
# outside a subagent. This is the assumption that decides whether the whole
# roster is enforcement or theatre, so it is recorded rather than buried.
[ -n "$AGENT" ] || exit 0

# Normalise to a repo-relative path.
#
# Windows spells the same path two ways and they do not prefix-match each other.
# The tool sends "C:/Users/x/proj/DECISIONS.md"; hook_root() under Git Bash
# yields "/c/Users/x/proj". The strip then misses, REL stays absolute, none of
# the ledger patterns below match, and the implementer boundary ALLOWS the write
# while reporting nothing -- the exact silent failure this hook exists to stop.
# Found by the T-005 verification harness, not by reading the code.
#
# _canon folds both spellings onto one: backslashes to slashes, a drive prefix
# to its MSYS form, no trailing slash. Case statements are used rather than sed
# -\l, which is GNU-only and would break on macOS.
ROOT="$(hook_root)"
_canon() {
  local p="${1//\\//}"
  case "$p" in
    [A-Za-z]:/*) p="/$(printf '%s' "${p%%:*}" | tr 'A-Z' 'a-z')/${p#*:/}" ;;
  esac
  printf '%s' "${p%/}"
}
REL="$(_canon "$FILE")"
_r="$(_canon "$ROOT")"
case "$REL" in "$_r"/*) REL="${REL#"$_r"/}" ;; esac
BASE="${REL##*/}"

# Still absolute means the path could not be placed inside the project: an
# unhandled path spelling, a symlinked checkout, or a genuinely external file.
# The matchers below carry tail patterns so the boundary stays closed either
# way, but say so -- a boundary quietly evaluating the wrong string is worse
# than one that is merely wrong.
case "$REL" in
  /*) hook_note "could not resolve '$FILE' against project root '$ROOT'; matching on the path tail." ;;
esac

# The three ledger documents at the repo root. Matched on the repo-relative
# path, not the basename: plugins/governed-dev/templates/DECISIONS.md is a
# shipped skeleton with the opposite role and is not a governance document
# here. CLAUDE.md is deliberately absent -- the implementer is required to
# keep working memory current, and gate check 4 fails the change if it does not.
_is_root_ledger() {
  case "$REL" in
    */templates/*) return 1 ;;
    DESIGN.md|DECISIONS.md|TASKS.md) return 0 ;;
    /*/DESIGN.md|/*/DECISIONS.md|/*/TASKS.md) return 0 ;;
  esac
  return 1
}

# Files the scribe owns. Everything else, code above all, is out of bounds.
# The absolute forms carry the same tail backstop, so an unresolvable path
# denies the implementer rather than the scribe -- erring toward the agent whose
# job the file actually is.
_is_scribe_file() {
  case "$REL" in
    */templates/*) return 1 ;;
    DECISIONS.md|TASKS.md|CLAUDE.md) return 0 ;;
    /*/DECISIONS.md|/*/TASKS.md|/*/CLAUDE.md) return 0 ;;
  esac
  return 1
}

case "$AGENT" in

  spec-guardian|reviewer|auditor)
    deny "The $AGENT agent is read-only and may not $TOOL any file, including $BASE.

It judges and reports; it does not change what it judges. An agent that can act
on its own finding cannot be trusted to report one it would rather not act on.

Hand the change to the implementer agent, or to the scribe if what needs
changing is DECISIONS.md, TASKS.md, or CLAUDE.md."
    ;;

  implementer)
    if _is_root_ledger; then
      deny "The implementer agent may not write $REL.

This is the load-bearing boundary (ADR-0007). DESIGN.md, DECISIONS.md and
TASKS.md are the records an implementer would otherwise edit to grant itself
permission -- resolving a spec wall by rewriting the spec, or closing a task by
declaring it closed. The whole separation of duties reduces to this one denial.

Instead:
  - DESIGN.md         needs an amendment. Stop and raise it with the human.
  - DECISIONS.md      the scribe agent writes ADRs and spec gaps.
  - TASKS.md          the scribe agent records status and commit hashes.

If you are here because DESIGN.md is silent on something you need, that is a
spec gap. Per .claude/rules/ambiguity.md: leave a '$_MARK' marker at the point
of contact and have the scribe record the matching entry. Do not decide it
yourself."
    fi
    ;;

  scribe)
    if ! _is_scribe_file; then
      deny "The scribe agent may not write $REL — it is scoped to DECISIONS.md,
TASKS.md, and CLAUDE.md.

The scribe records what was decided and what happened. An agent that both
writes the record and writes the code can make the two agree by changing
whichever is more convenient, which is the drift this system exists to catch.

Hand this to the implementer agent."
    fi
    ;;

  # An agent this hook does not know about. Not silently allowed: an unrecognised
  # name at an enforcement point usually means a roster changed and this file did
  # not, and the failure of a boundary must be louder than the work it blocks.
  *)
    deny "Agent type '$AGENT' has no boundary defined in boundary.sh, so this
$TOOL is denied rather than assumed safe.

Either the agent roster gained a member without a boundary, or this name is
wrong. Add the agent's boundary to plugins/governed-dev/hooks/boundary.sh and
its \`tools:\` allowlist to the agent definition, then retry."
    ;;
esac

exit 0
