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
# Bash and PowerShell carry a command string instead of a path. Without this the
# boundary inspects an empty FILE, matches nothing, and allows -- see ADR-0013.
CMD="$(hook_field '.tool_input.command')"

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
    # The ADRs themselves, since ADR-0029 split them out of DECISIONS.md.
    # Denying the file but not the directory it became would have quietly
    # reopened the exact route this boundary exists to close.
    docs/adr/*|*/docs/adr/*) return 0 ;;
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
    # ADR files and their archive: the scribe writes them and performs the
    # git mv that retires one (ADR-0029, .claude/rules/ledger.md).
    docs/adr/*|*/docs/adr/*) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# Shell tools. Bash and PowerShell carry a command, not a path, so everything
# above this point evaluates to nothing for them and the boundary would ALLOW.
# `echo x >> DECISIONS.md` is not a tool the path matchers watch. ADR-0013.
#
# WHAT THIS CAN AND CANNOT DO. Static analysis of a shell command is undecidable
# in general, and this makes no pretence otherwise. It closes the EXPEDIENT
# route -- the agent that hits a spec wall and reaches for a redirect because it
# is right there -- which is the failure ADR-0007 names. It does not stop
# deliberate evasion: `D=DECI; echo x >> ${D}SIONS.md` defeats it, as would any
# indirection through a variable, a glob, or a program's own file handling.
# Nothing at this layer stops a determined agent, and claiming otherwise would
# be the silent-degradation failure this repository is built against. The
# capability boundary is what carries that weight: the scribe and spec-guardian
# hold no shell at all, which is not a matcher that can be outwitted.
# ---------------------------------------------------------------------------

# Occurrences of a shipped template path are removed before matching. A
# templates/DECISIONS.md is a skeleton with the opposite role, not a governance
# document -- the same exemption the path matchers carry.
_cmd_no_templates() { printf '%s' "$CMD" | sed 's#[A-Za-z0-9_./-]*templates/[A-Za-z0-9_.-]*##g'; }

# Does the command name a root ledger document at all? Deliberately "names",
# not "writes to": the narrower test would have to decide which token is a
# redirect target, and every way of getting that wrong fails open. The
# implementer has Read and Grep for looking at these files, so over-blocking
# here costs it nothing it needs.
_cmd_names_ledger() {
  case "$(_cmd_no_templates)" in
    *DESIGN.md*|*DECISIONS.md*|*TASKS.md*|*docs/adr/*) return 0 ;;
  esac
  return 1
}

# Does the command contain a shell-level write? Benign redirects are removed
# first -- `2>&1` and `>/dev/null` are how every one of these agents runs a test
# suite quietly, and flagging them would make the boundary unusable and
# therefore switched off.
#
# Process-internal writes are NOT caught: `pytest` writing __pycache__, or
# `python -c "open(f,'w')"`, are invisible here unless they name a ledger file.
# That is the correct granularity for a syntactic check, and it is why the
# read-only agents' real protection is holding no Write or Edit tool.
_cmd_writes() {
  local c
  c="$(printf '%s' "$CMD" \
       | sed -e 's/[0-9]*>&[0-9-]*//g' \
             -e 's/&>>*[[:space:]]*\/dev\/null//g' \
             -e 's/[0-9]*>>*[[:space:]]*\/dev\/null//g')"
  case "$c" in
    *'>'*) return 0 ;;
  esac
  case " $c " in
    *' tee '*|*' sed -i'*|*' cp '*|*' mv '*|*' rm '*|*' dd '*|*' truncate '*\
    |*' install '*|*' touch '*|*' mkdir '*|*' rmdir '*|*' chmod '*|*' ln '*\
    |*' patch '*|*'perl -i'*|*' tee>'*) return 0 ;;
  esac
  # git subcommands that change the repository. `git add` and `git commit` are
  # writes to the project's state even though no file content is edited.
  case "$c" in
    *'git add'*|*'git commit'*|*'git push'*|*'git checkout'*|*'git restore'*\
    |*'git reset'*|*'git stash'*|*'git apply'*|*'git rm'*|*'git mv'*\
    |*'git merge'*|*'git rebase'*|*'git revert'*|*'git tag'*|*'git branch -'*) return 0 ;;
  esac
  return 1
}

if [ "$TOOL" = "Bash" ] || [ "$TOOL" = "PowerShell" ]; then
  case "$AGENT" in

    spec-guardian|reviewer|auditor)
      if _cmd_writes || _cmd_names_ledger; then
        deny "The $AGENT agent is read-only and may not run a $TOOL command that writes.

  $CMD

It judges and reports; it does not change what it judges. An agent that can act
on its own finding cannot be trusted to report one it would rather not act on --
and a shell redirect is a write like any other, which is the whole reason this
hook inspects commands and not just file paths.

Reading is fine: run the tests, run the gate, run git log or git diff. If
something needs changing, report it and hand it to the implementer, or to the
scribe for DECISIONS.md, TASKS.md, or CLAUDE.md."
      fi
      ;;

    implementer)
      if _cmd_names_ledger; then
        deny "The implementer agent may not run a $TOOL command naming DESIGN.md, DECISIONS.md, TASKS.md or docs/adr/.

  $CMD

This is the same boundary that denies Edit and Write on those files (ADR-0007),
enforced on the shell so that a redirect is not a way around it. It blocks the
command whether or not it writes, because deciding which token in a shell
command is a redirect target is not something this hook can get right often
enough to be trusted -- and a boundary that fails open is not a boundary.

Use Read and Grep to look at these files. To change one:
  - DESIGN.md         needs an amendment. Stop and raise it with the human.
  - DECISIONS.md      the scribe agent writes spec gaps; the index is generated.
  - docs/adr/         the scribe agent writes and archives ADRs.
  - TASKS.md          the scribe agent records status and commit hashes.

If you are here because DESIGN.md is silent on something you need, that is a
spec gap. Per .claude/rules/ambiguity.md: leave a '$_MARK' marker at the point
of contact and have the scribe record the matching entry. Do not decide it
yourself."
      fi
      ;;

    scribe)
      # The scribe's tools: list holds no shell, so arriving here means the
      # roster and this hook disagree. Deny rather than reason about it.
      deny "The scribe agent has no shell. Its \`tools:\` allowlist is Read and Edit,
so a $TOOL call means the agent definition and boundary.sh have diverged.

  $CMD

Fix the roster or this hook -- do not work around it. The scribe is denied a
shell precisely so that its write boundary cannot be reached around."
      ;;

    *)
      deny "Agent type '$AGENT' has no boundary defined in boundary.sh, so this
$TOOL command is denied rather than assumed safe.

Either the agent roster gained a member without a boundary, or this name is
wrong. Add the agent's boundary to plugins/governed-dev/hooks/boundary.sh and
its \`tools:\` allowlist to the agent definition, then retry."
      ;;
  esac
  exit 0
fi

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
  - DECISIONS.md      the scribe agent writes spec gaps; the index is generated.
  - docs/adr/         the scribe agent writes and archives ADRs.
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
