#!/usr/bin/env bash
#
# preflight.sh -- Setup. Checks that the things these hooks depend on are
# actually present, at install time, loudly. Fires on `claude --init-only` and
# `-p --init` (Setup event), and CI calls it directly as its own setup step
# (T-009/gate.yml) -- one script, not a install recipe kept in step with it by
# hand.
#
# The dependency that matters is jq. Without it boundary.sh cannot read
# agent_type and blocks every write, and stop-gate.sh cannot emit a block
# reason. Discovering that at the moment a boundary should have fired is the
# worst time to discover it, so it is reported here instead.
#
# Setup cannot block a Claude Code session -- its exit code is reported, not
# enforced, there. It is NOT run through the harness when CI calls it directly
# as a plain script (gate.yml), where exit 2 fails the job like any other
# step -- which is correct there: an unattended container has no one to notice
# a report.
#
# INSTALL VS. REPORT (T-025, ADR-0019): under CI ($CI truthy -- the convention
# GitHub Actions, GitLab CI and most others already set) a missing jq is
# installed automatically via apt-get, because a CI container is disposable
# and expected to be mutated by its own setup step. On an interactive
# developer machine this still only reports and advises, as it always has --
# silently running a package manager on someone's own machine on every session
# start is a materially more invasive act than doing the same thing in a
# container nobody is sitting at, and Prompt 8 did not ask to change that.
HOOK_NAME="Setup/preflight"
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FAIL=0

if ! have jq; then
  if [ -n "${CI:-}" ] && have apt-get; then
    hook_note "jq missing under CI; installing via apt-get."
    if sudo apt-get update -qq >/dev/null 2>&1 && sudo apt-get install -y -qq jq >/dev/null 2>&1; then
      hook_note "jq installed."
    fi
  fi
fi

if ! have jq; then
  FAIL=1
  { printf 'MISSING: jq\n\n'
    hook_jq_advice
    printf '\nUntil jq is installed:\n'
    printf '  - boundary.sh blocks every Edit and Write, because it cannot tell\n'
    printf '    which agent is writing and will not guess at an enforcement point\n'
    printf '  - stop-gate.sh blocks the end of every turn\n'
    printf '  - orient.sh cannot brief a new session\n'
    printf '  - activity.sh writes no audit records\n\n'
  } >&2
fi

if ! have git; then
  FAIL=1
  printf 'MISSING: git. Every hook here reads repository state; none can work without it.\n\n' >&2
fi

GATE="$(hook_gate)"
if [ ! -f "$GATE" ]; then
  FAIL=1
  { printf 'MISSING: the gate, expected at %s\n' "$GATE"
    printf 'The Stop and PostToolUse hooks have nothing to run. A check that cannot\n'
    printf 'run is a failed check, so both will block rather than skip.\n\n'
  } >&2
elif have bash; then
  # T-025: "verify the test runner and linter are present" delegates to the
  # gate's own checks 1-3 rather than a second copy of their detection logic
  # (`declared tooling` per-language sniffing lives in check-0[1-3]-*.sh only).
  # This runs the declared build/tests/lint, not merely a `which` probe -- a
  # heavier bar than "present", but the honest one: a linter that is on PATH
  # but misconfigured is not actually ready, and "present" was never the goal,
  # gate-ready was.
  if ! bash "$GATE" --fast; then
    FAIL=1
    printf '\nDeclared build/test/lint tooling did not pass -- see gate output above.\n\n' >&2
  fi
fi

# Windows only. hooks.json invokes every script as `bash <path>` in exec form,
# which spawns bash directly with no shell to find it -- so bash must be on
# PATH, not merely installed. ADR-0006 made Git Bash a prerequisite; exec form
# narrows that to bash-on-PATH, and an unmet narrowing means the hooks never run
# at all rather than failing. See SG-0006.
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    if ! have bash; then
      FAIL=1
      { printf 'WARNING: bash is not on PATH.\n'
        printf 'These hooks are registered as `bash <script>`; if the harness cannot\n'
        printf 'resolve bash on PATH, none of them run and nothing says so. Add Git\n'
        printf 'Bash to PATH, e.g. C:\\Program Files\\Git\\bin.\n\n'
      } >&2
    fi
    ;;
esac

if [ "$FAIL" = 0 ]; then
  hook_note "preflight passed: jq, git and the gate are present, and gate --fast ran clean."
  exit 0
fi

printf 'governed-dev preflight failed. The hooks are installed but will not all\n' >&2
printf 'work until the above is fixed. Setup cannot block, so this is a report.\n' >&2
exit 2
